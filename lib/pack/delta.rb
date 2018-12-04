require_relative "./numbers"

module Pack
  class Delta

    Copy = Struct.new(:offset, :size) do
      def self.parse(input, byte)
        value  = Numbers::PackedInt56LE.read(input, byte)
        offset = value & 0xffffffff
        size   = value >> 32

        Copy.new(offset, size)
      end

      def to_s
        bytes = Numbers::PackedInt56LE.write((size << 32) | offset)
        bytes[0] |= 0x80
        bytes.pack("C*")
      end
    end

    Insert = Struct.new(:data) do
      def self.parse(input, byte)
        Insert.new(input.read(byte))
      end

      def to_s
        [data.bytesize, data].pack("Ca*")
      end
    end

  end
end
