require "minitest/autorun"
require "command_helper"

describe Command::Status do
  include CommandHelper

  def assert_status(output)
    jit_cmd "status"
    assert_stdout(output)
  end

  it "lists files as untracked if they are not in the index" do
    write_file "committed.txt", ""
    jit_cmd "add", "."
    commit "commit message"

    write_file "file.txt", ""

    assert_status <<~STATUS
      ?? file.txt
    STATUS
  end

  it "lists untracked files in name order" do
    write_file "file.txt", ""
    write_file "another.txt", ""

    assert_status <<~STATUS
      ?? another.txt
      ?? file.txt
    STATUS
  end
end
