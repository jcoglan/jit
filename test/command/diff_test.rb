require "minitest/autorun"
require "command_helper"

describe Command::Diff do
  include CommandHelper

  def assert_diff(output)
    jit_cmd "diff"
    assert_stdout(output)
  end

  describe "with a file in the index" do
    before do
      write_file "file.txt", <<~FILE
        contents
      FILE
      jit_cmd "add", "."
    end

    it "diffs a file with modified contents" do
      write_file "file.txt", <<~FILE
        changed
      FILE

      assert_diff <<~DIFF
        diff --git a/file.txt b/file.txt
        index 12f00e9..5ea2ed4 100644
        --- a/file.txt
        +++ b/file.txt
      DIFF
    end
  end
end
