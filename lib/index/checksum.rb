require "digest/sha1"

class Index
  class Checksum

    EndOfFile = Class.new(StandardError)

    CHECKSUM_SIZE = 20

    def initialize(file)
      @file   = file
      @digest = Digest::SHA1.new
    end

    def write(data)
      @file.write(data)
      @digest.update(data)
    end

    def write_checksum
      @file.write(@digest.digest)
    end

    def read(size)
      data = @file.read(size)

      unless data.bytesize == size
        raise EndOfFile, "Unexpected end-of-file while reading index"
      end

      @digest.update(data)
      data
    end

    def verify_checksum
      sum = @file.read(CHECKSUM_SIZE)

      unless sum == @digest.digest
        raise Invalid, "Checksum does not match value stored on disk"
      end
    end

  end
end
