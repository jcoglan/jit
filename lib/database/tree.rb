class Database
  class Tree

    ENTRY_FORMAT = "Z*H40"

    attr_accessor :oid

    def self.build(entries)
      entries = entries.sort_by { |entry| entry.name.to_s }
      root    = Tree.new

      entries.each do |entry|
        path = entry.name.each_filename.to_a
        name = path.pop
        root.add_entry(path, name, entry)
      end

      root
    end

    def initialize
      @entries = {}
    end

    def add_entry(path, name, entry)
      if path.empty?
        @entries[name] = entry
      else
        tree = @entries[path.first] ||= Tree.new
        tree.add_entry(path.drop(1), name, entry)
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
end
