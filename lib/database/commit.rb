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
        value = parse_multiline(scanner, value)
        headers[key].push(value)
      end

      Commit.new(
        headers["parent"],
        headers["tree"].first,
        Author.parse(headers["author"].first),
        Author.parse(headers["committer"].first),
        scanner.rest.lstrip)
    end

    def self.parse_multiline(scanner, value)
      begin_line = /^-----BEGIN (.+)-----$/.match(value)
      return value unless begin_line

      name  = begin_line[1]
      lines = []

      loop do
        line = scanner.scan_until(/\n/)
        break if /^ *-----END #{ name }----- *$/.match(line)
        lines.push(line)
      end

      lines.join("\n")
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
      @message.lines
              .drop_while { |line| blank?(line) }
              .take_while { |line| not blank?(line) }
              .join(" ")
              .gsub(/\n(.)/, '\1')
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

    private

    def blank?(line)
      /^\s*$/.match(line)
    end

  end
end
