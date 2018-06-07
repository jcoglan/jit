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
end
