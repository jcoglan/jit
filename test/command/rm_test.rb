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
  end
end
