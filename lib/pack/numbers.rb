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

  end
end
