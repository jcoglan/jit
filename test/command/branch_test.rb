require "minitest/autorun"
require "command_helper"

describe Command::Branch do
  include CommandHelper

  describe "with a chain of commits" do
    before do
      messages = ["first", "second", "third"]

      messages.each do |message|
        write_file "file.txt", message
        jit_cmd "add", "."
        commit message
      end
    end

    it "creates a branch pointing at HEAD" do
      jit_cmd "branch", "topic"

      assert_equal repo.refs.read_head,
                   repo.refs.read_ref("topic")
    end

    it "fails for invalid branch names" do
      jit_cmd "branch", "^"

      assert_stderr <<~ERROR
        fatal: '^' is not a valid branch name.
      ERROR
    end

    it "fails for existing branch names" do
      jit_cmd "branch", "topic"
      jit_cmd "branch", "topic"

      assert_stderr <<~ERROR
        fatal: A branch named 'topic' already exists.
      ERROR
    end

    it "creates a branch pointing at HEAD's parent" do
      jit_cmd "branch", "topic", "HEAD^"

      head = repo.database.load(repo.refs.read_head)

      assert_equal head.parent,
                   repo.refs.read_ref("topic")
    end

    it "creates a branch pointing at HEAD's grandparent" do
      jit_cmd "branch", "topic", "@~2"

      head   = repo.database.load(repo.refs.read_head)
      parent = repo.database.load(head.parent)

      assert_equal parent.parent,
                   repo.refs.read_ref("topic")
    end

    it "creates a branch relative to another one" do
      jit_cmd "branch", "topic", "@~1"
      jit_cmd "branch", "another", "topic^"

      assert_equal resolve_revision("HEAD~2"),
                   repo.refs.read_ref("another")
    end

    it "creates a branch from a short commit ID" do
      commit_id = resolve_revision("@~2")
      jit_cmd "branch", "topic", repo.database.short_oid(commit_id)

      assert_equal commit_id,
                   repo.refs.read_ref("topic")
    end

    it "fails for invalid revisions" do
      jit_cmd "branch", "topic", "^"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '^'.
      ERROR
    end

    it "fails for invalid refs" do
      jit_cmd "branch", "topic", "no-such-branch"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: 'no-such-branch'.
      ERROR
    end

    it "fails for invalid parents" do
      jit_cmd "branch", "topic", "@^^^^"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '@^^^^'.
      ERROR
    end

    it "fails for invalid ancestors" do
      jit_cmd "branch", "topic", "@~50"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '@~50'.
      ERROR
    end
  end
end
