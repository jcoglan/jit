require "minitest/autorun"
require "command_helper"

require "rev_list"

describe Command::CherryPick do
  include CommandHelper

  def commit_tree(message, files)
    files.each do |path, contents|
      write_file path, contents
    end
    jit_cmd "add", "."
    commit message
  end

  describe "with two branches" do
    before do
      ["one", "two", "three", "four"].each do |message|
        commit_tree message, "f.txt" => message
      end

      jit_cmd "branch", "topic", "@~2"
      jit_cmd "checkout", "topic"

      commit_tree "five",  "g.txt" => "five"
      commit_tree "six",   "f.txt" => "six"
      commit_tree "seven", "g.txt" => "seven"
      commit_tree "eight", "g.txt" => "eight"

      jit_cmd "checkout", "master"
    end

    it "applies a commit on top of the current HEAD" do
      jit_cmd "cherry-pick", "topic~3"
      assert_status 0

      revs = RevList.new(repo, ["@~3.."])

      assert_equal ["five", "four", "three"],
                   revs.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "four",
        "g.txt" => "five"

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "five"
    end
  end
end
