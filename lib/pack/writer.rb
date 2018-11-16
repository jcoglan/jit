require "digest/sha1"
require "zlib"

require_relative "./numbers"

module Pack
  class Writer

    Entry = Struct.new(:oid, :type)

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

      rev_list.each do |object|
        add_to_pack_list(object)
        @progress&.tick
      end
      @progress&.stop
    end

    def add_to_pack_list(object)
      case object
      when Database::Commit
        @pack_list.push(Entry.new(object.oid, COMMIT))
      when Database::Entry
        type = object.tree? ? TREE : BLOB
        @pack_list.push(Entry.new(object.oid, type))
      end
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
      object = @database.load_raw(entry.oid)

      header = Numbers::VarIntLE.write(object.size)
      header[0] |= entry.type << 4

      write(header.pack("C*"))
      write(Zlib::Deflate.deflate(object.data, @compression))

      @progress&.tick(@offset)
    end

  end
end
