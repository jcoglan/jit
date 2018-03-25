require "minitest/autorun"
require "command_helper"

describe Command::Checkout do
  include CommandHelper

  describe "with a set of files" do
    def commit_all
      delete ".git/index"
      jit_cmd "add", "."
      commit "change"
    end

    def commit_and_checkout(revision)
      commit_all
      jit_cmd "checkout", revision
    end

    def assert_stale_file(filename)
      assert_stderr <<~ERROR
        error: Your local changes to the following files would be overwritten by checkout:
        \t#{ filename }
        Please commit your changes or stash them before you switch branches.
        Aborting
      ERROR
    end

    def assert_stale_directory(filename)
      assert_stderr <<~ERROR
        error: Updating the following directories would lose untracked files in them:
        \t#{ filename }

        Aborting
      ERROR
    end

    def assert_overwrite_conflict(filename)
      assert_stderr <<~ERROR
        error: The following untracked working tree files would be overwritten by checkout:
        \t#{ filename }
        Please move or remove them before you switch branches.
        Aborting
      ERROR
    end

    def assert_remove_conflict(filename)
      assert_stderr <<~ERROR
        error: The following untracked working tree files would be removed by checkout:
        \t#{ filename }
        Please move or remove them before you switch branches.
        Aborting
      ERROR
    end

    def assert_status(status)
      jit_cmd "status", "--porcelain"
      assert_stdout status
    end

    base_files = {
      "1.txt"             => "1",
      "outer/2.txt"       => "2",
      "outer/inner/3.txt" => "3"
    }

    before do
      base_files.each do |name, contents|
        write_file name, contents
      end
      jit_cmd "add", "."
      commit "first"
    end

    it "updates a changed file" do
      write_file "1.txt", "changed"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to update a modified file" do
      write_file "1.txt", "changed"
      commit_all

      write_file "1.txt", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "fails to update a modified-equal file" do
      write_file "1.txt", "changed"
      commit_all

      write_file "1.txt", "1"

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "fails to update a changed-mode file" do
      write_file "1.txt", "changed"
      commit_all

      make_executable "1.txt"

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "restores a deleted file" do
      write_file "1.txt", "changed"
      commit_all

      delete "1.txt"
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "restores files from a deleted directory" do
      write_file "outer/inner/3.txt", "changed"
      commit_all

      delete "outer"
      jit_cmd "checkout", "@^"

      assert_workspace \
        "1.txt"             => "1",
        "outer/inner/3.txt" => "3"

      assert_status <<~STATUS
        \ D outer/2.txt
      STATUS
    end

    it "fails to update a staged file" do
      write_file "1.txt", "changed"
      commit_all

      write_file "1.txt", "conflict"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "updates a staged-equal file" do
      write_file "1.txt", "changed"
      commit_all

      write_file "1.txt", "1"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to update a staged changed-mode file" do
      write_file "1.txt", "changed"
      commit_all

      make_executable "1.txt"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "fails to update an unindexed file" do
      write_file "1.txt", "changed"
      commit_all

      delete "1.txt"
      delete ".git/index"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "fails to update an unindexed and untracked file" do
      write_file "1.txt", "changed"
      commit_all

      delete "1.txt"
      delete ".git/index"
      jit_cmd "add", "."
      write_file "1.txt", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "1.txt"
    end

    it "fails to update an unindexed directory" do
      write_file "outer/inner/3.txt", "changed"
      commit_all

      delete "outer/inner"
      delete ".git/index"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/inner/3.txt"
    end

    it "fails to update with a file at a parent path" do
      write_file "outer/inner/3.txt", "changed"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/inner/3.txt"
    end

    it "fails to update with a staged file at a parent path" do
      write_file "outer/inner/3.txt", "changed"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/inner/3.txt"
    end

    it "fails to update with an unstaged file at a parent path" do
      write_file "outer/inner/3.txt", "changed"
      commit_all

      delete "outer/inner"
      delete ".git/index"
      jit_cmd "add", "."
      write_file "outer/inner", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/inner/3.txt"
    end

    it "fails to update with a file at a child path" do
      write_file "outer/2.txt", "changed"
      commit_all

      delete "outer/2.txt"
      write_file "outer/2.txt/extra.log", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/2.txt"
    end

    it "fails to update with a staged file at a child path" do
      write_file "outer/2.txt", "changed"
      commit_all

      delete "outer/2.txt"
      write_file "outer/2.txt/extra.log", "conflict"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/2.txt"
    end

    it "removes a file" do
      write_file "94.txt", "94"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "removes a file from an existing directory" do
      write_file "outer/94.txt", "94"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "removes a file from a new directory" do
      write_file "new/94.txt", "94"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_noent "new"
      assert_status ""
    end

    it "removes a file from a new nested directory" do
      write_file "new/inner/94.txt", "94"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_noent "new"
      assert_status ""
    end

    it "removes a file from a non-empty directory" do
      write_file "outer/94.txt", "94"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to remove a modified file" do
      write_file "outer/94.txt", "94"
      commit_all

      write_file "outer/94.txt", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/94.txt"
    end

    it "fails to remove a changed-mode file" do
      write_file "outer/94.txt", "94"
      commit_all

      make_executable "outer/94.txt"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/94.txt"
    end

    it "leaves a deleted file deleted" do
      write_file "outer/94.txt", "94"
      commit_all

      delete "outer/94.txt"
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "leaves a deleted directory deleted" do
      write_file "outer/inner/94.txt", "94"
      commit_all

      delete "outer/inner"
      jit_cmd "checkout", "@^"

      assert_workspace \
        "1.txt"       => "1",
        "outer/2.txt" => "2"

      assert_status <<~STATUS
        \ D outer/inner/3.txt
      STATUS
    end

    it "fails to remove a staged file" do
      write_file "outer/94.txt", "94"
      commit_all

      write_file "outer/94.txt", "conflict"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/94.txt"
    end

    it "fails to remove a staged changed-mode file" do
      write_file "outer/94.txt", "94"
      commit_all

      make_executable "outer/94.txt"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/94.txt"
    end

    it "leaves an unindexed file deleted" do
      write_file "outer/94.txt", "94"
      commit_all

      delete "outer/94.txt"
      delete ".git/index"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to remove an unindexed and untracked file" do
      write_file "outer/94.txt", "94"
      commit_all

      delete "outer/94.txt"
      delete ".git/index"
      jit_cmd "add", "."
      write_file "outer/94.txt", "conflict"

      jit_cmd "checkout", "@^"
      assert_remove_conflict "outer/94.txt"
    end

    it "leaves an unindexed directory deleted" do
      write_file "outer/inner/94.txt", "94"
      commit_all

      delete "outer/inner"
      delete ".git/index"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace \
        "1.txt"       => "1",
        "outer/2.txt" => "2"

      assert_status <<~STATUS
        D  outer/inner/3.txt
      STATUS
    end

    it "fails to remove with a file at a parent path" do
      write_file "outer/inner/94.txt", "94"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/inner/94.txt"
    end

    it "removes a file with a staged file at a parent path" do
      write_file "outer/inner/94.txt", "94"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace \
        "1.txt"       => "1",
        "outer/2.txt" => "2",
        "outer/inner" => "conflict"

      assert_status <<~STATUS
        A  outer/inner
        D  outer/inner/3.txt
      STATUS
    end

    it "fails to remove with an unstaged file at a parent path" do
      write_file "outer/inner/94.txt", "94"
      commit_all

      delete "outer/inner"
      delete ".git/index"
      jit_cmd "add", "."
      write_file "outer/inner", "conflict"

      jit_cmd "checkout", "@^"
      assert_remove_conflict "outer/inner"
    end

    it "fails to remove with a file at a child path" do
      write_file "outer/94.txt", "94"
      commit_all

      delete "outer/94.txt"
      write_file "outer/94.txt/extra.log", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/94.txt"
    end

    it "removes a file with a staged file at a child path" do
      write_file "outer/94.txt", "94"
      commit_all

      delete "outer/94.txt"
      write_file "outer/94.txt/extra.log", "conflict"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "adds a file" do
      delete "1.txt"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "adds a file to a directory" do
      delete "outer/2.txt"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "adds a directory" do
      delete "outer"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to add an untracked file" do
      delete "outer/2.txt"
      commit_all

      write_file "outer/2.txt", "conflict"

      jit_cmd "checkout", "@^"
      assert_overwrite_conflict "outer/2.txt"
    end

    it "fails to add an added file" do
      delete "outer/2.txt"
      commit_all

      write_file "outer/2.txt", "conflict"
      jit_cmd "add", "."

      jit_cmd "checkout", "@^"
      assert_stale_file "outer/2.txt"
    end

    it "adds a staged-equal file" do
      delete "outer/2.txt"
      commit_all

      write_file "outer/2.txt", "2"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to add with an untracked file at a parent path" do
      delete "outer/inner/3.txt"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"

      jit_cmd "checkout", "@^"
      assert_overwrite_conflict "outer/inner"
    end

    it "adds a file with an added file at a parent path" do
      delete "outer/inner/3.txt"
      commit_all

      delete "outer/inner"
      write_file "outer/inner", "conflict"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "fails to add with an untracked file at a child path" do
      delete "outer/2.txt"
      commit_all

      write_file "outer/2.txt/extra.log", "conflict"

      jit_cmd "checkout", "@^"
      assert_stale_directory "outer/2.txt"
    end

    it "adds a file with an added file at a child path" do
      delete "outer/2.txt"
      commit_all

      write_file "outer/2.txt/extra.log", "conflict"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "replaces a file with a directory" do
      delete "outer/inner"
      write_file "outer/inner", "in"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "replaces a directory with a file" do
      delete "outer/2.txt"
      write_file "outer/2.txt/nested.log", "nested"
      commit_and_checkout "@^"

      assert_workspace base_files
      assert_status ""
    end

    it "maintains workspace modifications" do
      write_file "1.txt", "changed"
      commit_all

      write_file "outer/2.txt", "hello"
      delete "outer/inner"
      jit_cmd "checkout", "@^"

      assert_workspace \
        "1.txt"       => "1",
        "outer/2.txt" => "hello"

      assert_status <<~STATUS
        \ M outer/2.txt
        \ D outer/inner/3.txt
      STATUS
    end

    it "maintains index modifications" do
      write_file "1.txt", "changed"
      commit_all

      write_file "outer/2.txt", "hello"
      write_file "outer/inner/4.txt", "world"
      jit_cmd "add", "."
      jit_cmd "checkout", "@^"

      assert_workspace base_files.merge(
        "outer/2.txt"       => "hello",
        "outer/inner/4.txt" => "world"
      )
      assert_status <<~STATUS
        M  outer/2.txt
        A  outer/inner/4.txt
      STATUS
    end
  end
end
