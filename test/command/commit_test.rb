require "minitest/autorun"
require "command_helper"

require "rev_list"

describe Command::Commit do
  include CommandHelper

  describe "committing to branches" do
    before do
      ["first", "second", "third"].each do |message|
        write_file "file.txt", message
        jit_cmd "add", "."
        commit message
      end

      jit_cmd "branch", "topic"
      jit_cmd "checkout", "topic"
    end

    def commit_change(content)
      write_file "file.txt", content
      jit_cmd "add", "."
      commit content
    end

    describe "on a branch" do
      it "advances a branch pointer" do
        head_before = repo.refs.read_ref("HEAD")

        commit_change "change"

        head_after   = repo.refs.read_ref("HEAD")
        branch_after = repo.refs.read_ref("topic")

        refute_equal head_before, head_after
        assert_equal head_after, branch_after

        assert_equal head_before,
                     resolve_revision("@^")
      end
    end

    describe "with a detached HEAD" do
      before do
        jit_cmd "checkout", "@"
      end

      it "advances HEAD" do
        head_before = repo.refs.read_ref("HEAD")
        commit_change "change"
        head_after = repo.refs.read_ref("HEAD")

        refute_equal head_before, head_after
      end

      it "does not advance the detached branch" do
        branch_before = repo.refs.read_ref("topic")
        commit_change "change"
        branch_after = repo.refs.read_ref("topic")

        assert_equal branch_before, branch_after
      end

      it "leaves HEAD a commit ahead of the branch" do
        commit_change "change"

        assert_equal repo.refs.read_ref("topic"),
                     resolve_revision("@^")
      end
    end

    describe "with concurrent branches" do
      before do
        jit_cmd "branch", "fork", "@^"
      end

      it "advances the branches from a shared parent" do
        commit_change "A"
        commit_change "B"

        jit_cmd "checkout", "fork"
        commit_change "C"

        refute_equal resolve_revision("topic"),
                     resolve_revision("fork")

        assert_equal resolve_revision("topic~3"),
                     resolve_revision("fork^")
      end
    end
  end

  describe "reusing messages" do
    before do
      write_file "file.txt", "1"
      jit_cmd "add", "."
      commit "first"
    end

    it "uses the message from another commit" do
      write_file "file.txt", "2"
      jit_cmd "add", "."
      jit_cmd "commit", "-C", "@"

      revs = RevList.new(repo, ["HEAD"])
      assert_equal ["first", "first"], revs.map { |commit| commit.message.strip }
    end
  end

  describe "amending commits" do
    before do
      ["first", "second", "third"].each do |message|
        write_file "file.txt", message
        jit_cmd "add", "."
        commit message
      end
    end

    it "replaces the last commit's message" do
      stub_editor("third [amended]\n") { jit_cmd "commit", "--amend" }
      revs = RevList.new(repo, ["HEAD"])

      assert_equal ["third [amended]", "second", "first"],
                   revs.map { |commit| commit.message.strip }
    end

    it "replaces the last commit's tree" do
      write_file "another.txt", "1"
      jit_cmd "add", "another.txt"
      jit_cmd "commit", "--amend"

      commit = load_commit("HEAD")
      diff   = repo.database.tree_diff(commit.parent, commit.oid)

      assert_equal ["another.txt", "file.txt"],
                   diff.keys.map(&:to_s).sort
    end
  end
end
