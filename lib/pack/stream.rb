require "digest/sha1"

module Pack
  class Stream

    attr_reader :digest, :offset

    def initialize(input, buffer = "")
      @input   = input
      @digest  = Digest::SHA1.new
      @offset  = 0
      @buffer  = new_byte_string.concat(buffer)
      @capture = nil
    end

    def capture
      @capture = new_byte_string
      result   = [yield, @capture]

      @digest.update(@capture)
      @capture = nil

      result
    end

    def verify_checksum
      unless read_buffered(20) == @digest.digest
        raise InvalidPack, "Checksum does not match value read from pack"
      end
    end

    def read(size)
      data = read_buffered(size)
      update_state(data)
      data
    end

    def read_nonblock(size)
      data = read_buffered(size, false)
      update_state(data)
      data
    end

    def readbyte
      read(1).bytes.first
    end

    def seek(amount, whence = IO::SEEK_SET)
      return unless amount < 0

      data = @capture.slice!(amount .. -1)
      @buffer.prepend(data)
      @offset += amount
    end

    private

    def new_byte_string
      String.new("", :encoding => Encoding::ASCII_8BIT)
    end

    def read_buffered(size, block = true)
      from_buf = @buffer.slice!(0, size)
      needed   = size - from_buf.bytesize
      from_io  = block ? @input.read(needed) : @input.read_nonblock(needed)

      from_buf.concat(from_io.to_s)

    rescue EOFError, Errno::EWOULDBLOCK
      from_buf
    end

    def update_state(data)
      @digest.update(data) unless @capture
      @offset += data.bytesize
      @capture&.concat(data)
    end

  end
end
