require "minitest/autorun"
require "command_helper"

describe Command::Add do
  include CommandHelper

  def assert_index(expected)
    repo.index.load
    actual = repo.index.each_entry.map { |entry| [entry.mode, entry.path] }
    assert_equal expected, actual
  end

  it "adds a regular file to the index" do
    write_file "hello.txt", "hello"

    jit_cmd "add", "hello.txt"

    assert_index [[0100644, "hello.txt"]]
  end

  it "adds an executable file to the index" do
    write_file "hello.txt", "hello"
    make_executable "hello.txt"

    jit_cmd "add", "hello.txt"

    assert_index [[0100755, "hello.txt"]]
  end

  it "adds multiple files to the index" do
    write_file "hello.txt", "hello"
    write_file "world.txt", "world"

    jit_cmd "add", "hello.txt", "world.txt"

    assert_index [[0100644, "hello.txt"], [0100644, "world.txt"]]
  end

  it "incrementally adds files to the index" do
    write_file "hello.txt", "hello"
    write_file "world.txt", "world"

    jit_cmd "add", "world.txt"

    assert_index [[0100644, "world.txt"]]

    jit_cmd "add", "hello.txt"

    assert_index [[0100644, "hello.txt"], [0100644, "world.txt"]]
  end

  it "adds a directory to the index" do
    write_file "a-dir/nested.txt", "content"

    jit_cmd "add", "a-dir"

    assert_index [[0100644, "a-dir/nested.txt"]]
  end

  it "adds the repository root to the index" do
    write_file "a/b/c/file.txt", "content"

    jit_cmd "add", "."

    assert_index [[0100644, "a/b/c/file.txt"]]
  end

  it "is silent on success" do
    write_file "hello.txt", "hello"

    jit_cmd "add", "hello.txt"

    assert_status 0
    assert_stdout ""
    assert_stderr ""
  end

  it "fails for non-existent files" do
    jit_cmd "add", "no-such-file"

    assert_stderr <<~ERROR
      fatal: pathspec 'no-such-file' did not match any files
    ERROR
    assert_status 128
    assert_index []
  end

  it "fails for unreadable files" do
    write_file "secret.txt", ""
    make_unreadable "secret.txt"

    jit_cmd "add", "secret.txt"

    assert_stderr <<~ERROR
      error: open('secret.txt'): Permission denied
      fatal: adding files failed
    ERROR
    assert_status 128
    assert_index []
  end

  it "fails if the index is locked" do
    write_file "file.txt", ""
    write_file ".git/index.lock", ""

    jit_cmd "add", "file.txt"

    assert_status 128
    assert_index []
  end
end
