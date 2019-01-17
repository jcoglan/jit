require "digest/sha1"
require "zlib"

require_relative "./expander"
require_relative "./reader"
require_relative "../temp_file"

module Pack
  class Indexer

    class PackFile
      attr_reader :digest

      def initialize(pack_dir, name)
        @file   = TempFile.new(pack_dir, name)
        @digest = Digest::SHA1.new
      end

      def write(data)
        @file.write(data)
        @digest.update(data)
      end

      def move(name)
        @file.write(@digest.digest)
        @file.move(name)
      end
    end

    def initialize(database, reader, stream, progress)
      @database = database
      @reader   = reader
      @stream   = stream
      @progress = progress

      @index   = {}
      @pending = Hash.new { |hash, oid| hash[oid] = [] }

      @pack_file  = PackFile.new(@database.pack_path, "tmp_pack")
      @index_file = PackFile.new(@database.pack_path, "tmp_idx")
    end

    def process_pack
      write_header
      write_objects
      write_checksum

      resolve_deltas
      write_index
    end

    private

    def write_header
      header = [SIGNATURE, VERSION, @reader.count].pack(HEADER_FORMAT)
      @pack_file.write(header)
    end

    def write_objects
      @progress&.start("Receiving objects", @reader.count)

      @reader.count.times do
        index_object
        @progress&.tick(@stream.offset)
      end
      @progress&.stop
    end

    def index_object
      offset       = @stream.offset
      record, data = @stream.capture { @reader.read_record }
      crc32        = Zlib.crc32(data)

      @pack_file.write(data)

      case record
      when Record
        oid = @database.hash_object(record)
        @index[oid] = [offset, crc32]
      when RefDelta
        @pending[record.base_oid].push([offset, crc32])
      end
    end

    def write_checksum
      @stream.verify_checksum

      filename = "pack-#{ @pack_file.digest.hexdigest }.pack"
      @pack_file.move(filename)

      path    = @database.pack_path.join(filename)
      @pack   = File.open(path, File::RDONLY)
      @reader = Reader.new(@pack)
    end

    def read_record_at(offset)
      @pack.seek(offset)
      @reader.read_record
    end

    def resolve_deltas
      deltas = @pending.reduce(0) { |n, (_, list)| n + list.size }
      @progress&.start("Resolving deltas", deltas)

      @index.to_a.each do |oid, (offset, _)|
        record = read_record_at(offset)
        resolve_delta_base(record, oid)
      end
      @progress&.stop
    end

    def resolve_delta_base(record, oid)
      pending = @pending.delete(oid)
      return unless pending

      pending.each do |offset, crc32|
        resolve_pending(record, offset, crc32)
      end
    end

    def resolve_pending(record, offset, crc32)
      delta  = read_record_at(offset)
      data   = Expander.expand(record.data, delta.delta_data)
      object = Record.new(record.type, data)
      oid    = @database.hash_object(object)

      @index[oid] = [offset, crc32]
      @progress&.tick

      resolve_delta_base(object, oid)
    end

    def write_index
      @object_ids = @index.keys.sort

      write_object_table
      write_crc32
      write_offsets
      write_index_checksum
    end

    def write_object_table
      header = [IDX_SIGNATURE, VERSION].pack("N2")
      @index_file.write(header)

      counts = Array.new(256, 0)
      total  = 0

      @object_ids.each { |oid| counts[oid[0..1].to_i(16)] += 1 }

      counts.each do |count|
        total += count
        @index_file.write([total].pack("N"))
      end

      @object_ids.each do |oid|
        @index_file.write([oid].pack("H40"))
      end
    end

    def write_crc32
      @object_ids.each do |oid|
        crc32 = @index[oid].last
        @index_file.write([crc32].pack("N"))
      end
    end

    def write_offsets
      large_offsets = []

      @object_ids.each do |oid|
        offset = @index[oid].first

        unless offset < IDX_MAX_OFFSET
          large_offsets.push(offset)
          offset = IDX_MAX_OFFSET | (large_offsets.size - 1)
        end
        @index_file.write([offset].pack("N"))
      end

      large_offsets.each do |offset|
        @index_file.write([offset].pack("Q>"))
      end
    end

    def write_index_checksum
      pack_digest = @pack_file.digest
      @index_file.write(pack_digest.digest)

      filename = "pack-#{ pack_digest.hexdigest }.idx"
      @index_file.move(filename)
    end

  end
end
