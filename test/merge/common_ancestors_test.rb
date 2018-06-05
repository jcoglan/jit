require "minitest/autorun"
require "fileutils"
require "pathname"

require "database"
require "merge/common_ancestors"

describe Merge::CommonAncestors do
  before { FileUtils.mkdir_p(db_path) }
  after  { FileUtils.rm_rf(db_path) }

  def db_path
    Pathname.new(File.expand_path("../test-database", __FILE__))
  end

  def database
    @database ||= Database.new(db_path)
  end

  def commit(parent, message)
    @commits ||= {}
    @time    ||= Time.now

    author = Database::Author.new("A. U. Thor", "author@example.com", @time)
    commit = Database::Commit.new(@commits[parent], "0" * 40, author, message)

    database.store(commit)
    @commits[message] = commit.oid
  end

  def chain(names)
    names.each_cons(2) { |parent, message| commit(parent, message) }
  end

  def ancestor(left, right)
    common = Merge::CommonAncestors.new(database, @commits[left], @commits[right])
    database.load(common.find).message
  end

  describe "with a linear history" do

    #   o---o---o---o
    #   A   B   C   D

    before do
      chain [nil, "A", "B", "C", "D"]
    end

    it "finds the common ancestor of a commit with itself" do
      assert_equal "D", ancestor("D", "D")
    end

    it "finds the commit that is an ancestor of the other" do
      assert_equal "B", ancestor("B", "D")
    end

    it "find the same commit if the arguments are reversed" do
      assert_equal "B", ancestor("D", "B")
    end

    it "finds a root commit" do
      assert_equal "A", ancestor("A", "C")
    end

    it "finds the intersection of a root commit with itself" do
      assert_equal "A", ancestor("A", "A")
    end
  end

  describe "with a forking history" do

    #          E   F   G   H
    #          o---o---o---o
    #         /         \
    #        /  C   D    \
    #   o---o---o---o     o---o
    #   A   B    \        J   K
    #             \
    #              o---o---o
    #              L   M   N

    before do
      chain [nil, "A", "B", "C", "D"]
      chain ["B", "E", "F", "G", "H"]
      chain ["G", "J", "K"]
      chain ["C", "L", "M", "N"]
    end

    it "finds the nearest fork point" do
      assert_equal "G", ancestor("H", "K")
    end

    it "finds an ancestor multiple forks away" do
      assert_equal "B", ancestor("D", "K")
    end

    it "finds the same fork point for any point on a branch" do
      assert_equal "C", ancestor("D", "L")
      assert_equal "C", ancestor("M", "D")
      assert_equal "C", ancestor("D", "N")
    end

    it "finds the commit that is an ancestor of the other" do
      assert_equal "E", ancestor("K", "E")
    end

    it "finds a root commit" do
      assert_equal "A", ancestor("J", "A")
    end
  end
end
