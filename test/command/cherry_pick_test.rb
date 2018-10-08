require "minitest/autorun"
require "command_helper"

require "rev_list"

describe Command::CherryPick do
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

    it "applies multiple non-conflicting commits" do
      jit_cmd "cherry-pick", "topic~3", "topic^", "topic"
      assert_status 0

      revs = RevList.new(repo, ["@~4.."])

      assert_equal ["eight", "seven", "five", "four"],
                   revs.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "four",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "four",
        "g.txt" => "eight"
    end

    it "stops when a list of commits includes a conflict" do
      jit_cmd "cherry-pick", "topic^", "topic~3"
      assert_status 1

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        DU g.txt
      STATUS
    end

    it "stops when a range of commits includes a conflict" do
      jit_cmd "cherry-pick", "..topic"
      assert_status 1

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU f.txt
      STATUS
    end

    it "refuses to commit in a conflicted state" do
      jit_cmd "cherry-pick", "..topic"
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
      jit_cmd "cherry-pick", "..topic"
      jit_cmd "cherry-pick", "--continue"

      assert_status 128

      assert_stderr <<~ERROR
        error: Committing is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
    end

    it "can continue after resolving the conflicts" do
      jit_cmd "cherry-pick", "..topic"

      write_file "f.txt", "six"
      jit_cmd "add", "f.txt"

      jit_cmd "cherry-pick", "--continue"
      assert_status 0

      revs = RevList.new(repo, ["@~5.."])

      assert_equal ["eight", "seven", "six", "five", "four"],
                   revs.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "six",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "six",
        "g.txt" => "eight"
    end

    it "can continue after commiting the resolved tree" do
      jit_cmd "cherry-pick", "..topic"

      write_file "f.txt", "six"
      jit_cmd "add", "f.txt"
      jit_cmd "commit"

      jit_cmd "cherry-pick", "--continue"
      assert_status 0

      revs = RevList.new(repo, ["@~5.."])

      assert_equal ["eight", "seven", "six", "five", "four"],
                   revs.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "six",
        "g.txt" => "eight"

      assert_workspace \
        "f.txt" => "six",
        "g.txt" => "eight"
    end

    describe "aborting in a conflicted state" do
      before do
        jit_cmd "cherry-pick", "..topic"
        jit_cmd "cherry-pick", "--abort"
      end

      it "exits successfully" do
        assert_status 0
        assert_stderr ""
      end

      it "resets to the old HEAD" do
        assert_equal "four", load_commit("HEAD").message.strip

        jit_cmd "status", "--porcelain"
        assert_stdout ""
      end

      it "removes the merge state" do
        refute repo.pending_commit.in_progress?
      end
    end

    describe "aborting in a committed state" do
      before do
        jit_cmd "cherry-pick", "..topic"
        jit_cmd "add", "."
        stub_editor("picked\n") { jit_cmd "commit" }

        jit_cmd "cherry-pick", "--abort"
      end

      it "exits with a warning" do
        assert_status 0
        assert_stderr <<~WARN
          warning: You seem to have moved HEAD. Not rewinding, check your HEAD!
        WARN
      end

      it "does not reset HEAD" do
        assert_equal "picked", load_commit("HEAD").message.strip

        jit_cmd "status", "--porcelain"
        assert_stdout ""
      end

      it "removes the merge state" do
        refute repo.pending_commit.in_progress?
      end
    end
  end

  describe "with merges" do

    #   f---f---f---f [master]
    #        \
    #         g---h---o---o [topic]
    #          \     /   /
    #           j---j---f [side]

    before do
      ["one", "two", "three", "four"].each do |message|
        commit_tree message, "f.txt" => message
      end

      jit_cmd "branch", "topic", "@~2"
      jit_cmd "checkout", "topic"
      commit_tree "five", "g.txt" => "five"
      commit_tree "six",  "h.txt" => "six"

      jit_cmd "branch", "side", "@^"
      jit_cmd "checkout", "side"
      commit_tree "seven", "j.txt" => "seven"
      commit_tree "eight", "j.txt" => "eight"
      commit_tree "nine",  "f.txt" => "nine"

      jit_cmd "checkout", "topic"
      jit_cmd "merge", "side^", "-m", "merge side^"
      jit_cmd "merge", "side", "-m", "merge side"

      jit_cmd "checkout", "master"
    end

    it "refuses to cherry-pick a merge without specifying a parent" do
      jit_cmd "cherry-pick", "topic"
      assert_status 1

      oid = resolve_revision "topic"

      assert_stderr <<~ERROR
        error: commit #{ oid } is a merge but no -m option was given
      ERROR
    end

    it "refuses to cherry-pick a non-merge commit with mainline" do
      jit_cmd "cherry-pick", "-m", "1", "side"
      assert_status 1

      oid = resolve_revision "side"

      assert_stderr <<~ERROR
        error: mainline was specified but commit #{ oid } is not a merge
      ERROR
    end

    it "cherry-picks a merge based on its first parent" do
      jit_cmd "cherry-pick", "-m", "1", "topic^"
      assert_status 0

      assert_index \
        "f.txt" => "four",
        "j.txt" => "eight"

      assert_workspace \
        "f.txt" => "four",
        "j.txt" => "eight"
    end

    it "cherry-picks a merge based on its second parent" do
      jit_cmd "cherry-pick", "-m", "2", "topic^"
      assert_status 0

      assert_index \
        "f.txt" => "four",
        "h.txt" => "six"

      assert_workspace \
        "f.txt" => "four",
        "h.txt" => "six"
    end

    it "resumes cherry-picking merges after a conflict" do
      jit_cmd "cherry-pick", "-m", "1", "topic", "topic^"
      assert_status 1

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU f.txt
      STATUS

      write_file "f.txt", "resolved"
      jit_cmd "add", "f.txt"
      jit_cmd "cherry-pick", "--continue"
      assert_status 0

      revs = RevList.new(repo, ["@~3.."])

      assert_equal ["merge side^", "merge side", "four"],
                   revs.map { |commit| commit.message.strip }

      assert_index \
        "f.txt" => "resolved",
        "j.txt" => "eight"

      assert_workspace \
        "f.txt" => "resolved",
        "j.txt" => "eight"
    end
  end
end
