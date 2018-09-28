require "minitest/autorun"
require "command_helper"

require "rev_list"

describe Command::Revert do
  include CommandHelper

  def commit_tree(message, files)
    @time ||= Time.now
    @time +=  10

    files.each do |path, contents|
      write_file path, contents
    end
    jit_cmd "add", "."
    commit message, @time
  end

  describe "with a chain of commits" do
    before do
      ["one", "two", "three", "four"].each do |message|
        commit_tree message, "f.txt" => message
      end

      commit_tree "five",  "g.txt" => "five"
      commit_tree "six",   "f.txt" => "six"
      commit_tree "seven", "g.txt" => "seven"
      commit_tree "eight", "g.txt" => "eight"
    end

    it "reverts a commit on top of the current HEAD" do
      jit_cmd "revert", "@~2"
      assert_status 0

      revs = RevList.new(repo, ["@~3.."])

      assert_equal ['Revert "six"', "eight", "seven"],
                   revs.map { |commit| commit.title_line.strip }

      assert_index \
        "f.txt" => "four",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "eight"
    end

    it "fails to revert a content conflict" do
      jit_cmd "revert", "@~4"
      assert_status 1

      short = repo.database.short_oid(resolve_revision("@~4"))

      assert_workspace \
        "g.txt" => "eight",
        "f.txt" => <<~FILE
          <<<<<<< HEAD
          six=======
          three>>>>>>> parent of #{ short }... four
        FILE

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU f.txt
      STATUS
    end

    it "fails to revert a modify/delete conflict" do
      jit_cmd "revert", "@~3"
      assert_status 1

      assert_workspace \
        "f.txt" => "six",
        "g.txt" => "eight"

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UD g.txt
      STATUS
    end

    it "continues a conflicted revert" do
      jit_cmd "revert", "@~3"
      jit_cmd "add", "g.txt"

      jit_cmd "revert", "--continue"
      assert_status 0

      commits = RevList.new(repo, ["@~3.."]).to_a
      assert_equal [commits[1].oid], commits[0].parents

      assert_equal ['Revert "five"', "eight", "seven"],
                   commits.map { |commit| commit.title_line.strip }

      assert_index \
        "f.txt" => "six",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "six",
        "g.txt" => "eight"
    end

    it "commits after a conflicted revert" do
      jit_cmd "revert", "@~3"
      jit_cmd "add", "g.txt"

      jit_cmd "commit"
      assert_status 0

      commits = RevList.new(repo, ["@~3.."]).to_a
      assert_equal [commits[1].oid], commits[0].parents

      assert_equal ['Revert "five"', "eight", "seven"],
                   commits.map { |commit| commit.title_line.strip }
    end

    it "applies multiple non-conflicting commits" do
      jit_cmd "revert", "@", "@^", "@^^"
      assert_status 0

      revs = RevList.new(repo, ["@~4.."])

      assert_equal ['Revert "six"', 'Revert "seven"', 'Revert "eight"', "eight"],
                   revs.map { |commit| commit.title_line.strip }

      assert_index \
        "f.txt" => "four",
        "g.txt" => "five"

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "five"
    end

    it "stops when a list of commits includes a conflict" do
      jit_cmd "revert", "@^", "@"
      assert_status 1

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU g.txt
      STATUS
    end

    it "stops when a range of commits includes a conflict" do
      jit_cmd "revert", "@~5..@~2"
      assert_status 1

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UD g.txt
      STATUS
    end

    it "refuses to commit in a conflicted state" do
      jit_cmd "revert", "@~5..@~2"
      jit_cmd "commit"

      assert_status 128

      assert_stderr <<~ERROR
        error: Committing is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
    end

    it "refuses to continue in a conflicted state" do
      jit_cmd "revert", "@~5..@~2"
      jit_cmd "revert", "--continue"

      assert_status 128

      assert_stderr <<~ERROR
        error: Committing is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
    end

    it "can continue after resolving the conflicts" do
      jit_cmd "revert", "@~4..@^"

      write_file "g.txt", "five"
      jit_cmd "add", "g.txt"

      jit_cmd "revert", "--continue"
      assert_status 0

      revs = RevList.new(repo, ["@~4.."])

      assert_equal ['Revert "five"', 'Revert "six"', 'Revert "seven"', "eight"],
                   revs.map { |commit| commit.title_line.strip }

      assert_index "f.txt" => "four"
      assert_workspace "f.txt" => "four"
    end

    it "can continue after commiting the resolved tree" do
      jit_cmd "revert", "@~4..@^"

      write_file "g.txt", "five"
      jit_cmd "add", "g.txt"
      jit_cmd "commit"

      jit_cmd "revert", "--continue"
      assert_status 0

      revs = RevList.new(repo, ["@~4.."])

      assert_equal ['Revert "five"', 'Revert "six"', 'Revert "seven"', "eight"],
                   revs.map { |commit| commit.title_line.strip }

      assert_index "f.txt" => "four"
      assert_workspace "f.txt" => "four"
    end

    describe "aborting in a conflicted state" do
      before do
        jit_cmd "revert", "@~5..@^"
        jit_cmd "revert", "--abort"
      end

      it "exits successfully" do
        assert_status 0
        assert_stderr ""
      end

      it "resets to the old HEAD" do
        assert_equal "eight", load_commit("HEAD").message.strip

        jit_cmd "status", "--porcelain"
        assert_stdout ""
      end

      it "removes the merge state" do
        refute repo.pending_commit.in_progress?
      end
    end

    describe "aborting in a committed state" do
      before do
        jit_cmd "revert", "@~5..@^"
        jit_cmd "add", "."
        stub_editor("reverted\n") { jit_cmd "commit" }

        jit_cmd "revert", "--abort"
      end

      it "exits with a warning" do
        assert_status 0
        assert_stderr <<~WARN
          warning: You seem to have moved HEAD. Not rewinding, check your HEAD!
        WARN
      end

      it "does not reset HEAD" do
        assert_equal "reverted", load_commit("HEAD").message.strip

        jit_cmd "status", "--porcelain"
        assert_stdout ""
      end

      it "removes the merge state" do
        refute repo.pending_commit.in_progress?
      end
    end
  end
end
