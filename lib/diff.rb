require_relative "./diff/hunk"
require_relative "./diff/myers"

module Diff
  SYMBOLS = {
    :eql => " ",
    :ins => "+",
    :del => "-"
  }

  Line = Struct.new(:number, :text)

  Edit = Struct.new(:type, :a_line, :b_line) do
    def to_s
      line = a_line || b_line
      SYMBOLS.fetch(type) + line.text
    end
  end

  def self.lines(document)
    document = document.lines if document.is_a?(String)
    document.map.with_index { |text, i| Line.new(i + 1, text) }
  end

  def self.diff(a, b)
    Myers.diff(Diff.lines(a), Diff.lines(b))
  end

  def self.diff_hunks(a, b)
    Hunk.filter(Diff.diff(a, b))
  end
end
