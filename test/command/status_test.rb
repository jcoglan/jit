require "minitest/autorun"
require "command_helper"

describe Command::Status do
  include CommandHelper

  def assert_status(output)
    jit_cmd "status", "--porcelain"
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

  describe "index/workspace changes" do
    before do
      write_file "1.txt", "one"
      write_file "a/2.txt", "two"
      write_file "a/b/3.txt", "three"

      jit_cmd "add", "."
      commit "commit message"
    end

    it "prints nothing when no files are changed" do
      assert_status ""
    end

    it "reports files with modified contents" do
      write_file "1.txt", "changed"
      write_file "a/2.txt", "modified"

      assert_status <<~STATUS
        \ M 1.txt
        \ M a/2.txt
      STATUS
    end

    it "reports modified files with unchanged size" do
      write_file "a/b/3.txt", "hello"

      assert_status <<~STATUS
        \ M a/b/3.txt
      STATUS
    end

    it "reports files with changed modes" do
      make_executable "a/2.txt"

      assert_status <<~STATUS
        \ M a/2.txt
      STATUS
    end

    it "prints nothing if a file is touched" do
      touch "1.txt"

      assert_status ""
    end

    it "reports deleted files" do
      delete "a/2.txt"

      assert_status <<~STATUS
        \ D a/2.txt
      STATUS
    end

    it "reports files in deleted directories" do
      delete "a"

      assert_status <<~STATUS
        \ D a/2.txt
        \ D a/b/3.txt
      STATUS
    end
  end

  describe "head/index changes" do
    before do
      write_file "1.txt", "one"
      write_file "a/2.txt", "two"
      write_file "a/b/3.txt", "three"

      jit_cmd "add", "."
      commit "first commit"
    end

    it "reports a file added to a tracked directory" do
      write_file "a/4.txt", "four"
      jit_cmd "add", "."

      assert_status <<~STATUS
        A  a/4.txt
      STATUS
    end

    it "reports a file added to an utracked directory" do
      write_file "d/e/5.txt", "five"
      jit_cmd "add", "."

      assert_status <<~STATUS
        A  d/e/5.txt
      STATUS
    end

    it "reports modified modes" do
      make_executable "1.txt"
      jit_cmd "add", "."

      assert_status <<~STATUS
        M  1.txt
      STATUS
    end

    it "reports modified contents" do
      write_file "a/b/3.txt", "changed"
      jit_cmd "add", "."

      assert_status <<~STATUS
        M  a/b/3.txt
      STATUS
    end

    it "reports deleted files" do
      delete "1.txt"
      delete ".git/index"
      jit_cmd "add", "."

      assert_status <<~STATUS
        D  1.txt
      STATUS
    end

    it "reports all deleted files inside directories" do
      delete "a"
      delete ".git/index"
      jit_cmd "add", "."

      assert_status <<~STATUS
        D  a/2.txt
        D  a/b/3.txt
      STATUS
    end
  end
end
