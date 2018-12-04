require "stringio"

require_relative "./delta"
require_relative "./numbers"

module Pack
  class Expander

    attr_reader :source_size, :target_size

    def self.expand(source, delta)
      new(delta).expand(source)
    end

    def initialize(delta)
      @delta = StringIO.new(delta)

      @source_size = read_size
      @target_size = read_size
    end

    def expand(source)
      check_size(source, @source_size)
      target = ""

      until @delta.eof?
        byte = @delta.readbyte

        if byte < 0x80
          insert = Delta::Insert.parse(@delta, byte)
          target.concat(insert.data)
        else
          copy = Delta::Copy.parse(@delta, byte)
          size = (copy.size == 0) ? GIT_MAX_COPY : copy.size
          target.concat(source.byteslice(copy.offset, size))
        end
      end

      check_size(target, @target_size)
      target
    end

    private

    def read_size
      Numbers::VarIntLE.read(@delta, 7)[1]
    end

    def check_size(buffer, size)
      raise "failed to apply delta" unless buffer.bytesize == size
    end

  end
end
