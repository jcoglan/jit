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
