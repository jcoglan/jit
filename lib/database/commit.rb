require_relative "./author"

class Database
  class Commit

    attr_accessor :oid
    attr_reader :parent, :tree, :author

    def self.parse(scanner)
      headers = {}

      loop do
        line = scanner.scan_until(/\n/).strip
        break if line == ""

        key, value = line.split(/ +/, 2)
        headers[key] = value
      end

      Commit.new(
        headers["parent"],
        headers["tree"],
        Author.parse(headers["author"]),
        scanner.rest)
    end

    def initialize(parent, tree, author, message)
      @parent  = parent
      @tree    = tree
      @author  = author
      @message = message
    end

    def title_line
      @message.lines.first
    end

    def type
      "commit"
    end

    def to_s
      lines = []

      lines.push("tree #{ @tree }")
      lines.push("parent #{ @parent }") if @parent
      lines.push("author #{ @author }")
      lines.push("committer #{ @author }")
      lines.push("")
      lines.push(@message)

      lines.join("\n")
    end

  end
end
