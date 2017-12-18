class Database
  class Commit

    attr_accessor :oid

    def initialize(parent, tree, author, message)
      @parent  = parent
      @tree    = tree
      @author  = author
      @message = message
    end

    def type
      "commit"
    end

    def to_s
      lines = []

      lines << "tree #{ @tree }"
      lines << "parent #{ @parent }" if @parent
      lines << "author #{ @author }"
      lines << "committer #{ @author }"
      lines << ""
      lines << @message

      lines.join("\n")
    end

  end
end
