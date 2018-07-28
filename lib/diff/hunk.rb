module Diff

  HUNK_CONTEXT = 3

  Hunk = Struct.new(:a_starts, :b_start, :edits) do
    def self.filter(edits)
      hunks  = []
      offset = 0

      loop do
        offset += 1 while edits[offset]&.type == :eql
        return hunks if offset >= edits.size

        offset -= HUNK_CONTEXT + 1

        a_starts = (offset < 0) ? []  : edits[offset].a_lines.map(&:number)
        b_start  = (offset < 0) ? nil : edits[offset].b_line.number

        hunks.push(Hunk.new(a_starts, b_start, []))
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
      a_lines = edits.map(&:a_lines).transpose
      offsets = a_lines.map.with_index { |lines, i| format("-", lines, a_starts[i]) }

      offsets.push(format("+", edits.map(&:b_line), b_start))
      sep = "@" * offsets.size

      [sep, *offsets, sep].join(" ")
    end

    private

    def format(sign, lines, start)
      lines = lines.compact
      start = lines.first&.number || start || 0

      "#{ sign }#{ start },#{ lines.size }"
    end
  end

end
