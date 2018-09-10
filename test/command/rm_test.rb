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
  end
end
