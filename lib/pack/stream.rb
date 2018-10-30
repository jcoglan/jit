require "digest/sha1"

module Pack
  class Stream

    attr_reader :digest, :offset

    def initialize(input)
      @input  = input
      @digest = Digest::SHA1.new
      @offset = 0
    end

    def verify_checksum
      unless @input.read(20) == @digest.digest
        raise InvalidPack, "Checksum does not match value read from pack"
      end
    end

    def read(size)
      data = @input.read(size)
      update_state(data)
      data
    end

    def readbyte
      read(1).bytes.first
    end

    private

    def update_state(data)
      @digest.update(data)
      @offset += data.bytesize
    end

  end
end
