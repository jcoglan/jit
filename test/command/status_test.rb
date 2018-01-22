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

  it "lists untracked directories, not their contents" do
    write_file "file.txt", ""
    write_file "dir/another.txt", ""

    assert_status <<~STATUS
      ?? dir/
      ?? file.txt
    STATUS
  end

  it "lists untracked files inside tracked directories" do
    write_file "a/b/inner.txt", ""
    jit_cmd "add", "."
    commit "commit message"

    write_file "a/outer.txt", ""
    write_file "a/b/c/file.txt", ""

    assert_status <<~STATUS
      ?? a/b/c/
      ?? a/outer.txt
    STATUS
  end

  it "does not list empty untracked directories" do
    mkdir "outer"

    assert_status ""
  end

  it "lists untracked directories that indirectly contain files" do
    write_file "outer/inner/file.txt", ""

    assert_status <<~STATUS
      ?? outer/
    STATUS
  end
end
