class Tree
  ENTRY_FORMAT = "Z*H40"

  attr_accessor :oid

  def initialize(entries)
    @entries = entries
  end

  def type
    "tree"
  end

  def to_s
    entries = @entries.sort_by(&:name).map do |entry|
      ["#{ entry.mode } #{ entry.name }", entry.oid].pack(ENTRY_FORMAT)
    end

    entries.join("")
  end
end
