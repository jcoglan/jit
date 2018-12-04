module Pack
  module Numbers

    module VarIntLE
      def self.write(value, shift)
        bytes = []
        mask  = 2 ** shift - 1

        until value <= mask
          bytes.push(0x80 | value & mask)
          value >>= shift

          mask, shift = 0x7f, 7
        end

        bytes + [value]
      end

      def self.read(input, shift)
        first = input.readbyte
        value = first & (2 ** shift - 1)

        byte = first

        until byte < 0x80
          byte   = input.readbyte
          value |= (byte & 0x7f) << shift
          shift += 7
        end

        [first, value]
      end
    end

    module PackedInt56LE
      def self.write(value)
        bytes = [0]

        (0...7).each do |i|
          byte = (value >> (8 * i)) & 0xff
          next if byte == 0

          bytes[0] |= 1 << i
          bytes.push(byte)
        end

        bytes
      end

      def self.read(input, header)
        value = 0

        (0...7).each do |i|
          next if header & (1 << i) == 0
          value |= input.readbyte << (8 * i)
        end

        value
      end
    end

  end
end
