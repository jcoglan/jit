require "minitest/autorun"
require "command_helper"

describe Command::Rm do
  include CommandHelper

  describe "with a single file" do
    before do
      write_file "f.txt", "1"

      jit_cmd "add", "."
      commit "first"
    end

    it "exits successfully" do
      jit_cmd "rm", "f.txt"
      assert_status 0
    end

    it "removes a file from the index" do
      jit_cmd "rm", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
    end

    it "removes a file from the workspace" do
      jit_cmd "rm", "f.txt"
      assert_workspace({})
    end

    it "succeeds if the file is not in the workspace" do
      delete "f.txt"
      jit_cmd "rm", "f.txt"

      assert_status 0

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
    end

    it "fails if the file is not in the index" do
      jit_cmd "rm", "nope.txt"
      assert_status 128
      assert_stderr "fatal: pathspec 'nope.txt' did not match any files\n"
    end

    it "fails if the file has unstaged changes" do
      write_file "f.txt", "2"
      jit_cmd "rm", "f.txt"

      assert_stderr <<~ERROR
        error: the following file has local modifications:
            f.txt
      ERROR

      assert_status 1

      repo.index.load
      assert repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "2"
    end

    it "fails if the file has uncommitted changes" do
      write_file "f.txt", "2"
      jit_cmd "add", "f.txt"
      jit_cmd "rm", "f.txt"

      assert_stderr <<~ERROR
        error: the following file has changes staged in the index:
            f.txt
      ERROR

      assert_status 1

      repo.index.load
      assert repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "2"
    end

    it "forces removal of unstaged changes" do
      write_file "f.txt", "2"
      jit_cmd "rm", "-f", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
      assert_workspace({})
    end

    it "forces removal of uncommitted changes" do
      write_file "f.txt", "2"
      jit_cmd "add", "f.txt"
      jit_cmd "rm", "-f", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
      assert_workspace({})
    end

    it "removes a file only from the index" do
      jit_cmd "rm", "--cached", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "1"
    end

    it "removes a file from the index if it has unstaged changes" do
      write_file "f.txt", "2"
      jit_cmd "rm", "--cached", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "2"
    end

    it "removes a file from the index if it has uncommitted changes" do
      write_file "f.txt", "2"
      jit_cmd "add", "f.txt"
      jit_cmd "rm", "--cached", "f.txt"

      repo.index.load
      refute repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "2"
    end

    it "does not remove a file with both uncommitted and unstaged changes" do
      write_file "f.txt", "2"
      jit_cmd "add", "f.txt"
      write_file "f.txt", "3"
      jit_cmd "rm", "--cached", "f.txt"

      assert_stderr <<~ERROR
        error: the following file has staged content different from both the file and the HEAD:
            f.txt
      ERROR

      assert_status 1

      repo.index.load
      assert repo.index.tracked_file?("f.txt")
      assert_workspace "f.txt" => "3"
    end
  end
end
