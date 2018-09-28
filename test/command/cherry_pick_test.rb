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

    it "fails to apply a content conflict" do
      jit_cmd "cherry-pick", "topic^^"
      assert_status 1

      short = repo.database.short_oid(resolve_revision("topic^^"))

      assert_workspace "f.txt" => <<~FILE
          <<<<<<< HEAD
          four=======
          six>>>>>>> #{ short }... six
        FILE

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU f.txt
      STATUS
    end

    it "fails to apply a modify/delete conflict" do
      jit_cmd "cherry-pick", "topic"
      assert_status 1

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "eight"

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        DU g.txt
      STATUS
    end

    it "continues a conflicted cherry-pick" do
      jit_cmd "cherry-pick", "topic"
      jit_cmd "add", "g.txt"

      jit_cmd "cherry-pick", "--continue"
      assert_status 0

      commits = RevList.new(repo, ["@~3.."]).to_a
      assert_equal [commits[1].oid], commits[0].parents

      assert_equal ["eight", "four", "three"],
                   commits.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "four",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "eight"
    end

    it "commits after a conflicted cherry-pick" do
      jit_cmd "cherry-pick", "topic"
      jit_cmd "add", "g.txt"

      jit_cmd "commit"
      assert_status 0

      commits = RevList.new(repo, ["@~3.."]).to_a
      assert_equal [commits[1].oid], commits[0].parents

      assert_equal ["eight", "four", "three"],
                   commits.map { |commit| commit.message.strip }
    end
  end
end
