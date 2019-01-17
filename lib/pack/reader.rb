require "zlib"

require_relative "./expander"
require_relative "./numbers"

module Pack
  class Reader

    attr_reader :count

    def initialize(input)
      @input = input
    end

    def read_header
      data = @input.read(HEADER_SIZE)
      signature, version, @count = data.unpack(HEADER_FORMAT)

      unless signature == SIGNATURE
        raise InvalidPack, "bad pack signature: #{ signature }"
      end

      unless version == VERSION
        raise InvalidPack, "unsupported pack version: #{ version }"
      end
    end

    def read_record
      type, _ = read_record_header

      case type
      when COMMIT, TREE, BLOB
        Record.new(TYPE_CODES.key(type), read_zlib_stream)
      when REF_DELTA
        read_ref_delta
      end
    end

    def read_info
      type, size = read_record_header

      case type
      when COMMIT, TREE, BLOB
        Record.new(TYPE_CODES.key(type), size)

      when REF_DELTA
        delta = read_ref_delta
        size  = Expander.new(delta.delta_data).target_size

        RefDelta.new(delta.base_oid, size)
      end
    end

    private

    def read_record_header
      byte, size = Numbers::VarIntLE.read(@input, 4)
      type = (byte >> 4) & 0x7

      [type, size]
    end

    def read_ref_delta
      base_oid = @input.read(20).unpack("H40").first
      RefDelta.new(base_oid, read_zlib_stream)
    end

    def read_zlib_stream
      stream = Zlib::Inflate.new
      string = ""
      total  = 0

      until stream.finished?
        data   = @input.read_nonblock(256)
        total += data.bytesize

        string.concat(stream.inflate(data))
      end
      @input.seek(stream.total_in - total, IO::SEEK_CUR)

      string
    end

  end
end
