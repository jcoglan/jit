class Database
  class Tree

    ENTRY_FORMAT = "Z*H40"
    TREE_MODE    = 040000
    TREE_TYPE    = "tree"

    attr_accessor :oid
    attr_reader :entries

    def self.parse(scanner)
      entries = {}

      until scanner.eos?
        mode = scanner.scan_until(/ /).strip.to_i(8)
        name = scanner.scan_until(/\0/)[0..-2]

        oid = scanner.peek(20).unpack("H40").first
        scanner.pos += 20

        entries[name] = Entry.new(oid, mode)
      end

      Tree.new(entries)
    end

    def initialize(entries = {})
      @entries = entries
    end

    def type
      TREE_TYPE
    end

  end
end
