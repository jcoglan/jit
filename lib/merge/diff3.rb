require_relative "../diff"

module Merge
  class Diff3

    Clean = Struct.new(:lines) do
      def to_s(*)
        lines.join("")
      end
    end

    Conflict = Struct.new(:o_lines, :a_lines, :b_lines) do
      def to_s(a_name = nil, b_name = nil)
        text = ""
        separator(text, "<", a_name)
        a_lines.each { |line| text.concat(line) }
        separator(text, "=")
        b_lines.each { |line| text.concat(line) }
        separator(text, ">", b_name)
        text
      end

      def separator(text, char, name = nil)
        text.concat(char * 7)
        text.concat(" #{ name }") if name
        text.concat("\n")
      end
    end

    Result = Struct.new(:chunks) do
      def clean?
        chunks.none? { |chunk| chunk.is_a?(Conflict) }
      end

      def to_s(a_name = nil, b_name = nil)
        chunks.map { |chunk| chunk.to_s(a_name, b_name) }.join("")
      end
    end

    def self.merge(o, a, b)
      o = o.lines if o.is_a?(String)
      a = a.lines if a.is_a?(String)
      b = b.lines if b.is_a?(String)

      Diff3.new(o, a, b).merge
    end

    def initialize(o, a, b)
      @o, @a, @b = o, a, b
    end

    def merge
      setup
      generate_chunks
      Result.new(@chunks)
    end

    def setup
      @chunks = []
      @line_o = @line_a = @line_b = 0

      @match_a = match_set(@a)
      @match_b = match_set(@b)
    end

    def match_set(file)
      matches = {}

      Diff.diff(@o, file).each do |edit|
        next unless edit.type == :eql
        matches[edit.a_line.number] = edit.b_line.number
      end

      matches
    end

    def generate_chunks
      loop do
        i = find_next_mismatch

        if i == 1
          o, a, b = find_next_match

          if a and b
            emit_chunk(o, a, b)
          else
            emit_final_chunk
            return
          end

        elsif i
          emit_chunk(@line_o + i, @line_a + i, @line_b + i)

        else
          emit_final_chunk
          return
        end
      end
    end

    def find_next_mismatch
      i = 1
      while in_bounds?(i) and
            match?(@match_a, @line_a, i) and
            match?(@match_b, @line_b, i)
        i += 1
      end
      in_bounds?(i) ? i : nil
    end

    def in_bounds?(i)
      @line_o + i <= @o.size or
      @line_a + i <= @a.size or
      @line_b + i <= @b.size
    end

    def match?(matches, offset, i)
      matches[@line_o + i] == offset + i
    end

    def find_next_match
      o = @line_o + 1
      until o > @o.size or (@match_a.has_key?(o) and @match_b.has_key?(o))
        o += 1
      end
      [o, @match_a[o], @match_b[o]]
    end

    def emit_chunk(o, a, b)
      write_chunk(
        @o[@line_o ... o - 1],
        @a[@line_a ... a - 1],
        @b[@line_b ... b - 1])

      @line_o, @line_a, @line_b = o - 1, a - 1, b - 1
    end

    def emit_final_chunk
      write_chunk(
        @o[@line_o .. -1],
        @a[@line_a .. -1],
        @b[@line_b .. -1])
    end

    def write_chunk(o, a, b)
      if a == o or a == b
        @chunks.push(Clean.new(b))
      elsif b == o
        @chunks.push(Clean.new(a))
      else
        @chunks.push(Conflict.new(o, a, b))
      end
    end

  end
end
