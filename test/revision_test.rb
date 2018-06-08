require "minitest/autorun"
require "revision"

describe Revision do
  describe "parse" do
    def assert_parse(expression, tree)
      assert_equal tree, Revision.parse(expression)
    end

    it "parses HEAD" do
      assert_parse "HEAD",
        Revision::Ref.new("HEAD")
    end

    it "parses @" do
      assert_parse "@",
        Revision::Ref.new("HEAD")
    end

    it "parses a branch name" do
      assert_parse "master",
        Revision::Ref.new("master")
    end

    it "parses an object ID" do
      assert_parse "3803cb6dc4ab0a852c6762394397dc44405b5ae4",
        Revision::Ref.new("3803cb6dc4ab0a852c6762394397dc44405b5ae4")
    end

    it "parses a parent ref" do
      assert_parse "HEAD^",
        Revision::Parent.new(Revision::Ref.new("HEAD"), 1)
    end

    it "parses a chain of parent refs" do
      assert_parse "master^^^",
        Revision::Parent.new(
          Revision::Parent.new(
            Revision::Parent.new(
              Revision::Ref.new("master"),
              1),
            1),
          1)
    end

    it "parses a parent ref with a number" do
      assert_parse "@^2",
        Revision::Parent.new(Revision::Ref.new("HEAD"), 2)
    end

    it "parses an ancestor ref" do
      assert_parse "@~3",
        Revision::Ancestor.new(
          Revision::Ref.new("HEAD"),
          3)
    end

    it "parses a chain of parents and ancestors" do
      assert_parse "@~2^^~3",
        Revision::Ancestor.new(
          Revision::Parent.new(
            Revision::Parent.new(
              Revision::Ancestor.new(
                Revision::Ref.new("HEAD"),
                2),
              1),
            1),
          3)
    end
  end
end
