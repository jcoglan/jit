class Tree
  ENTRY_FORMAT = "Z*H40"

  attr_accessor :oid

  def self.build(entries)
    entries.sort_by! { |entry| entry.name.to_s }
    root = Tree.new

    entries.each do |entry|
      root.add_entry(entry.parent_directories, entry)
    end

    root
  end

  def initialize
    @entries = {}
  end

  def add_entry(parents, entry)
    if parents.empty?
      @entries[entry.basename] = entry
    else
      tree = @entries[parents.first.basename] ||= Tree.new
      tree.add_entry(parents.drop(1), entry)
    end
  end

  def traverse(&block)
    @entries.each do |name, entry|
      entry.traverse(&block) if entry.is_a?(Tree)
    end
    block.call(self)
  end

  def mode
    Entry::DIRECTORY_MODE
  end

  def type
    "tree"
  end

  def to_s
    entries = @entries.map do |name, entry|
      ["#{ entry.mode } #{ name }", entry.oid].pack(ENTRY_FORMAT)
    end

    entries.join("")
  end
end
