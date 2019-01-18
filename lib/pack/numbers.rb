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

    module VarIntBE
      def self.write(value)
        bytes = [value & 0x7f]

        until (value >>= 7) == 0
          value -= 1
          bytes.push(0x80 | value & 0x7f)
        end

        bytes.reverse.pack("C*")
      end

      def self.read(input)
        byte  = input.readbyte
        value = byte & 0x7f

        until byte < 0x80
          byte  = input.readbyte
          value = ((value + 1) << 7) | (byte & 0x7f)
        end

        value
      end
    end

    module PackedInt56LE
      def self.write(value)
        bytes = (0..6).map { |i| (value >> (8 * i)) & 0xff }

        flags  = bytes.map.with_index { |b, i| b == 0 ? 0 : 1 << i }
        header = flags.reduce(0) { |a, b| a | b }

        [header] + bytes.reject { |b| b == 0 }
      end

      def self.read(input, header)
        flags = (0..6).reject { |i| header & (1 << i) == 0 }
        bytes = flags.map { |i| input.readbyte << (8 * i) }

        bytes.reduce(0) { |a, b| a | b }
      end
    end

  end
end
