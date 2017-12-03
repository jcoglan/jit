class Commit
  attr_accessor :oid

  def initialize(tree, author, message)
    @tree    = tree
    @author  = author
    @message = message
  end

  def type
    "commit"
  end

  def to_s
    lines = [
      "tree #{ @tree }",
      "author #{ @author }",
      "committer #{ @author }",
      "",
      @message
    ]

    lines.join("\n")
  end
end
