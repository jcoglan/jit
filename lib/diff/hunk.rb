module Diff

  HUNK_CONTEXT = 3

  Hunk = Struct.new(:a_start, :b_start, :edits) do
    def self.filter(edits)
      hunks  = []
      offset = 0

      loop do
        offset += 1 while edits[offset]&.type == :eql
        return hunks if offset >= edits.size

        offset -= HUNK_CONTEXT + 1

        a_start = (offset < 0) ? 0 : edits[offset].a_line.number
        b_start = (offset < 0) ? 0 : edits[offset].b_line.number

        hunks.push(Hunk.new(a_start, b_start, []))
        offset = Hunk.build(hunks.last, edits, offset)
      end
    end

    def self.build(hunk, edits, offset)
      counter = -1

      until counter == 0
        hunk.edits.push(edits[offset]) if offset >= 0 and counter > 0

        offset += 1
        break if offset >= edits.size

        case edits[offset + HUNK_CONTEXT]&.type
        when :ins, :del
          counter = 2 * HUNK_CONTEXT + 1
        else
          counter -= 1
        end
      end

      offset
    end

    def header
      a_offset = offsets_for(:a_line, a_start).join(",")
      b_offset = offsets_for(:b_line, b_start).join(",")

      "@@ -#{ a_offset } +#{ b_offset } @@"
    end

    private

    def offsets_for(line_type, default)
      lines = edits.map(&line_type).compact
      start = lines.first&.number || default

      [start, lines.size]
    end
  end

end
