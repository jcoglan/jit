require "minitest/autorun"
require "command_helper"

describe Command::Merge do
  include CommandHelper

  def commit_tree(message, files)
    files.each do |path, contents|
      write_file path, contents
    end
    jit_cmd "add", "."
    commit message
  end

  describe "merging an ancestor" do
    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "merge", "@^"
    end

    it "prints the up-to-date message" do
      assert_stdout "Already up to date.\n"
    end

    it "does not change the repository state" do
      commit = load_commit("@")
      assert_equal "C", commit.message

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end

  describe "fast-forward merge" do
    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "branch", "topic", "@^^"
      jit_cmd "checkout", "topic"

      set_stdin "M"
      jit_cmd "merge", "master"
    end

    it "prints the fast-forward message" do
      a, b = ["master^^", "master"].map { |rev| resolve_revision(rev) }
      assert_stdout <<~MSG
        Updating #{ repo.database.short_oid(a) }..#{ repo.database.short_oid(b) }
        Fast-forward
      MSG
    end

    it "updates the current branch HEAD" do
      commit = load_commit("@")
      assert_equal "C", commit.message

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end

  describe "unconflicted merge with two files" do

    #   A   B   M
    #   o---o---o
    #    \     /
    #     `---o
    #         C

    before do
      commit_tree "root",
        "f.txt" => "1",
        "g.txt" => "1"

      jit_cmd "branch", "topic"
      jit_cmd "checkout", "topic"
      commit_tree "right", "g.txt" => "2"

      jit_cmd "checkout", "master"
      commit_tree "left", "f.txt" => "2"

      set_stdin "merge topic branch"
      jit_cmd "merge", "topic"
    end

    it "puts the combined changes in the workspace" do
      assert_workspace \
        "f.txt" => "2",
        "g.txt" => "2"
    end

    it "leaves the status clean" do
      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end

    it "writes a commit with the old HEAD and the merged commit as parents" do
      commit     = load_commit("@")
      old_head   = load_commit("@^")
      merge_head = load_commit("topic")

      assert_equal [old_head.oid, merge_head.oid], commit.parents
    end
  end

  describe "multiple common ancestors" do

    #   A   B   C       M1  H   M2
    #   o---o---o-------o---o---o
    #        \         /       /
    #         o---o---o G     /
    #         D  E \         /
    #               `-------o
    #                       F

    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "branch", "topic", "master^"
      jit_cmd "checkout", "topic"
      commit_tree "D", "g.txt" => "1"
      commit_tree "E", "g.txt" => "2"
      commit_tree "F", "g.txt" => "3"

      jit_cmd "branch", "joiner", "topic^"
      jit_cmd "checkout", "joiner"
      commit_tree "G", "h.txt" => "1"

      jit_cmd "checkout", "master"
    end

    it "performs the first merge" do
      set_stdin "merge joiner"
      jit_cmd "merge", "joiner"
      assert_status 0

      assert_workspace \
        "f.txt" => "3",
        "g.txt" => "2",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end

    it "performs the second merge" do
      set_stdin "merge joiner"
      jit_cmd "merge", "joiner"

      commit_tree "H", "f.txt" => "4"

      set_stdin "merge topic"
      jit_cmd "merge", "topic"
      assert_status 0

      assert_workspace \
        "f.txt" => "4",
        "g.txt" => "3",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end
end
