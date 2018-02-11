require_relative "./diff/myers"

module Diff
  SYMBOLS = {
    :eql => " ",
    :ins => "+",
    :del => "-"
  }

  Edit = Struct.new(:type, :text) do
    def to_s
      SYMBOLS.fetch(type) + text
    end
  end

  def self.lines(document)
    document.is_a?(String) ? document.lines : document
  end

  def self.diff(a, b)
    Myers.diff(Diff.lines(a), Diff.lines(b))
  end
end
