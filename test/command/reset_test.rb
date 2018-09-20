require "minitest/autorun"
require "command_helper"

describe Command::Reset do
  include CommandHelper

  describe "with no HEAD commit" do
    before do
      write_file "a.txt", "1"
      write_file "outer/b.txt", "2"
      write_file "outer/inner/c.txt", "3"

      jit_cmd "add", "."
    end

    def assert_unchanged_workspace
      assert_workspace \
        "a.txt"             => "1",
        "outer/b.txt"       => "2",
        "outer/inner/c.txt" => "3"
    end

    it "removes everything from the index" do
      jit_cmd "reset"

      assert_index({})
      assert_unchanged_workspace
    end

    it "removes a single file from the index" do
      jit_cmd "reset", "a.txt"

      assert_index \
        "outer/b.txt"       => "2",
        "outer/inner/c.txt" => "3"

      assert_unchanged_workspace
    end

    it "removes a directory from the index" do
      jit_cmd "reset", "outer"

      assert_index "a.txt" => "1"

      assert_unchanged_workspace
    end
  end

  describe "with a HEAD commit" do
    before do
      write_file "a.txt", "1"
      write_file "outer/b.txt", "2"
      write_file "outer/inner/c.txt", "3"

      jit_cmd "add", "."
      commit "first"

      write_file "outer/b.txt", "4"
      jit_cmd "add", "."
      commit "second"

      jit_cmd "rm", "a.txt"
      write_file "outer/d.txt", "5"
      write_file "outer/inner/c.txt", "6"
      jit_cmd "add", "."
      write_file "outer/e.txt", "7"

      @head_oid = repo.refs.read_head
    end

    def assert_unchanged_head
      assert_equal @head_oid, repo.refs.read_head
    end

    def assert_unchanged_workspace
      assert_workspace \
        "outer/b.txt"       => "4",
        "outer/d.txt"       => "5",
        "outer/e.txt"       => "7",
        "outer/inner/c.txt" => "6"
    end

    it "restores a file removed from the index" do
      jit_cmd "reset", "a.txt"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "4",
        "outer/d.txt"       => "5",
        "outer/inner/c.txt" => "6"

      assert_unchanged_head
      assert_unchanged_workspace
    end

    it "resets a file modified in the index" do
      jit_cmd "reset", "outer/inner"

      assert_index \
        "outer/b.txt"       => "4",
        "outer/d.txt"       => "5",
        "outer/inner/c.txt" => "3"

      assert_unchanged_head
      assert_unchanged_workspace
    end

    it "removes a file added to the index" do
      jit_cmd "reset", "outer/d.txt"

      assert_index \
        "outer/b.txt"       => "4",
        "outer/inner/c.txt" => "6"

      assert_unchanged_head
      assert_unchanged_workspace
    end

    it "resets a file to a specific commit" do
      jit_cmd "reset", "@^", "outer/b.txt"

      assert_index \
        "outer/b.txt"       => "2",
        "outer/d.txt"       => "5",
        "outer/inner/c.txt" => "6"

      assert_unchanged_head
      assert_unchanged_workspace
    end

    it "resets the whole index" do
      jit_cmd "reset"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "4",
        "outer/inner/c.txt" => "3"

      assert_unchanged_head
      assert_unchanged_workspace
    end

    it "resets the whole index and moves HEAD" do
      jit_cmd "reset", "@^"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "2",
        "outer/inner/c.txt" => "3"

      assert_equal repo.database.load(@head_oid).parent,
                   repo.refs.read_head

      assert_unchanged_workspace
    end

    it "moves HEAD and leaves the index unchanged" do
      jit_cmd "reset", "--soft", "@^"

      assert_index \
        "outer/b.txt"       => "4",
        "outer/d.txt"       => "5",
        "outer/inner/c.txt" => "6"

      assert_equal repo.database.load(@head_oid).parent,
                   repo.refs.read_head

      assert_unchanged_workspace
    end

    it "resets the index and workspace" do
      write_file "a.txt/nested", "remove me"
      write_file "outer/b.txt", "10"
      delete "outer/inner"

      jit_cmd "reset", "--hard"
      assert_unchanged_head

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "4",
        "outer/inner/c.txt" => "3"

      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        ?? outer/e.txt
      STATUS
    end

    it "lets you return to the previous state using ORIG_HEAD" do
      jit_cmd "reset", "--hard", "@^"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "2",
        "outer/inner/c.txt" => "3"

      jit_cmd "reset", "--hard", "ORIG_HEAD"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "4",
        "outer/inner/c.txt" => "3"
    end
  end
end
