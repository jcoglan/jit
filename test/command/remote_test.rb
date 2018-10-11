require "minitest/autorun"
require "command_helper"

describe Command::Remote do
  include CommandHelper

  describe "adding a remote" do
    before do
      jit_cmd(*%w[remote add origin ssh://example.com/repo])
    end

    it "fails to add an existing remote" do
      jit_cmd "remote", "add", "origin", "url"
      assert_status 128
      assert_stderr "fatal: remote origin already exists.\n"
    end

    it "lists the remote" do
      jit_cmd "remote"

      assert_stdout <<~REMOTES
        origin
      REMOTES
    end

    it "lists the remote with its URLs" do
      jit_cmd "remote", "--verbose"

      assert_stdout <<~REMOTES
        origin\tssh://example.com/repo (fetch)
        origin\tssh://example.com/repo (push)
      REMOTES
    end

    it "sets a catch-all fetch refspec" do
      jit_cmd "config", "--local", "--get-all", "remote.origin.fetch"

      assert_stdout <<~REFSPEC
        +refs/heads/*:refs/remotes/origin/*
      REFSPEC
    end
  end

  describe "adding a remote with tracking branches" do
    before do
      jit_cmd(*%w[remote add origin ssh://example.com/repo -t master -t topic])
    end

    it "sets a fetch refspec for each branch" do
      jit_cmd "config", "--local", "--get-all", "remote.origin.fetch"

      assert_stdout <<~REFSPEC
        +refs/heads/master:refs/remotes/origin/master
        +refs/heads/topic:refs/remotes/origin/topic
      REFSPEC
    end
  end

  describe "removing a remote" do
    before do
      jit_cmd(*%w[remote add origin ssh://example.com/repo])
    end

    it "removes the remote" do
      jit_cmd "remote", "remove", "origin"
      assert_status 0

      jit_cmd "remote"
      assert_stdout ""
    end

    it "fails to remove a missing remote" do
      jit_cmd "remote", "remove", "no-such"
      assert_status 128
      assert_stderr "fatal: No such remote: no-such\n"
    end
  end
end
