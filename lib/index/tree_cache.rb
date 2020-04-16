class Index
  class TreeCache

    def self.ext_name
      "TREE"
    end

    def initialize(index)
      @index = index
      @root  = {}
    end

    def parse(scanner)
      prefix = []

      until scanner.eos?
        node, name, trees = Node.parse(scanner)

        tree = prefix.reduce(@root) { |t, (n, _)| t[n].children }
        tree[name] = node

        prefix.push([name, trees])
        prefix.pop until prefix.empty? or prefix.last[1] > 0
        prefix.last[1] -= 1 unless prefix.empty?
      end
    end

    def to_s(buffer = nil, tree = @root)
      buffer ||= String.new("", :encoding => Encoding::ASCII_8BIT)

      tree.each do |name, node|
        node.write(buffer, name)
        to_s(buffer, node.children)
      end

      buffer
    end

    Node = Struct.new(:oid, :entries, :children) do
      def self.parse(scanner)
        name    = scanner.scan_until(/\0/)[0..-2]
        entries = scanner.scan_until(/ /).to_i
        trees   = scanner.scan_until(/\n/).to_i

        if entries >= 0
          oid = scanner.peek(20).unpack("H40").first
          scanner.pos += 20
        else
          oid = nil
        end

        node = Node.new(oid, entries, {})
        [node, name, trees]
      end

      def write(buffer, name)
        buffer.concat("#{ name }\0#{ entries } #{ children.size }\n")
        buffer.concat([oid].pack("H40")) if oid
      end
    end

  end
end
