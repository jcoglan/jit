require_relative "./author"

class Database
  class Commit

    attr_accessor :oid
    attr_reader :parents, :tree, :author, :committer, :message

    def self.parse(scanner)
      headers = Hash.new { |hash, key| hash[key] = [] }

      loop do
        line = scanner.scan_until(/\n/).strip
        break if line == ""

        key, value = line.split(/ +/, 2)
        headers[key].push(value)
      end

      Commit.new(
        headers["parent"],
        headers["tree"].first,
        Author.parse(headers["author"].first),
        Author.parse(headers["committer"].first),
        scanner.rest)
    end

    def initialize(parents, tree, author, committer, message)
      @parents   = parents
      @tree      = tree
      @author    = author
      @committer = committer
      @message   = message
    end

    def merge?
      @parents.size > 1
    end

    def parent
      @parents.first
    end

    def date
      @committer.time
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
      lines.concat(@parents.map { |oid| "parent #{ oid }" })
      lines.push("author #{ @author }")
      lines.push("committer #{ @committer }")
      lines.push("")
      lines.push(@message)

      lines.join("\n")
    end

  end
end
