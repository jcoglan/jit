require "digest/sha1"
require "zlib"

require_relative "./compressor"
require_relative "./entry"
require_relative "./numbers"

module Pack
  class Writer

    def initialize(output, database, options = {})
      @output   = output
      @database = database
      @digest   = Digest::SHA1.new
      @offset   = 0

      @compression = options.fetch(:compression, Zlib::DEFAULT_COMPRESSION)
      @progress    = options[:progress]
    end

    def write_objects(rev_list)
      prepare_pack_list(rev_list)
      compress_objects
      write_header
      write_entries
      @output.write(@digest.digest)
    end

    private

    def write(data)
      @output.write(data)
      @digest.update(data)
      @offset += data.bytesize
    end

    def prepare_pack_list(rev_list)
      @pack_list = []
      @progress&.start("Counting objects")

      rev_list.each do |object, path|
        add_to_pack_list(object, path)
        @progress&.tick
      end
      @progress&.stop
    end

    def add_to_pack_list(object, path)
      info = @database.load_info(object.oid)
      @pack_list.push(Entry.new(object.oid, info, path))
    end

    def compress_objects
      compressor = Compressor.new(@database, @progress)
      @pack_list.each { |entry| compressor.add(entry) }
      compressor.build_deltas
    end

    def write_header
      header = [SIGNATURE, VERSION, @pack_list.size].pack(HEADER_FORMAT)
      write(header)
    end

    def write_entries
      count = @pack_list.size
      @progress&.start("Writing objects", count) unless @output == STDOUT

      @pack_list.each { |entry| write_entry(entry) }
      @progress&.stop
    end

    def write_entry(entry)
      write_entry(entry.delta.base) if entry.delta

      return if entry.offset
      entry.offset = @offset

      object = entry.delta || @database.load_raw(entry.oid)

      header = Numbers::VarIntLE.write(entry.packed_size, 4)
      header[0] |= entry.packed_type << 4

      write(header.pack("C*"))
      write(entry.delta_prefix)
      write(Zlib::Deflate.deflate(object.data, @compression))

      @progress&.tick(@offset)
    end

  end
end
