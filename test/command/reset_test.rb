require "minitest/autorun"
require "command_helper"

describe Command::Reset do
  include CommandHelper

  def assert_index(contents)
    files = {}
    repo.index.load

    repo.index.each_entry do |entry|
      files[entry.path] = repo.database.load(entry.oid).data
    end

    assert_equal(contents, files)
  end

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

      jit_cmd "rm", "a.txt"
      write_file "outer/d.txt", "4"
      write_file "outer/inner/c.txt", "5"
      jit_cmd "add", "."
      write_file "outer/e.txt", "6"
    end

    def assert_unchanged_workspace
      assert_workspace \
        "outer/b.txt"       => "2",
        "outer/d.txt"       => "4",
        "outer/e.txt"       => "6",
        "outer/inner/c.txt" => "5"
    end

    it "restores a file removed from the index" do
      jit_cmd "reset", "a.txt"

      assert_index \
        "a.txt"             => "1",
        "outer/b.txt"       => "2",
        "outer/d.txt"       => "4",
        "outer/inner/c.txt" => "5"

      assert_unchanged_workspace
    end

    it "resets a file modified in the index" do
      jit_cmd "reset", "outer/inner"

      assert_index \
        "outer/b.txt"       => "2",
        "outer/d.txt"       => "4",
        "outer/inner/c.txt" => "3"

      assert_unchanged_workspace
    end

    it "removes a file added to the index" do
      jit_cmd "reset", "outer/d.txt"

      assert_index \
        "outer/b.txt"       => "2",
        "outer/inner/c.txt" => "5"

      assert_unchanged_workspace
    end
  end
end
