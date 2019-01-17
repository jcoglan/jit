require "minitest/autorun"
require "fileutils"
require "find"

require "command_helper"
require "remote_repo"
require "rev_list"

ENV["NO_PROGRESS"] = "1"

describe Command::Fetch do
  include CommandHelper

  def write_commit(message)
    @remote.write_file "#{ message }.txt", message
    @remote.jit_cmd "add", "."
    @remote.jit_cmd "commit", "-m", message
  end

  def commits(repo, revs, options = {})
    RevList.new(repo, revs, options).map do |commit|
      repo.database.short_oid(commit.oid)
    end
  end

  def assert_object_count(n)
    count = 0
    Find.find(repo_path.join(".git", "objects")) do |path|
      count += 1 if File.file?(path)
    end
    assert_equal(n, count)
  end

  def jit_path
    File.expand_path("../../../bin/jit", __FILE__)
  end

  describe "with a single branch in the remote repository" do
    before do
      @remote = RemoteRepo.new("fetch-remote")
      @remote.jit_cmd "init", @remote.repo_path.to_s

      ["one", "dir/two", "three"].each { |msg| write_commit msg }

      jit_cmd "remote", "add", "origin", "file://#{ @remote.repo_path }"
      jit_cmd "config", "remote.origin.uploadpack", "#{ jit_path } upload-pack"
    end

    after do
      FileUtils.rm_rf(@remote.repo_path)
    end

    it "displays a new branch being fetched" do
      jit_cmd "fetch"
      assert_status 0

      assert_stderr <<~OUTPUT
        From file://#{ @remote.repo_path }
         * [new branch] master -> origin/master
      OUTPUT
    end

    it "maps the remote's heads/* to the local's remotes/origin/*" do
      jit_cmd "fetch"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/remotes/origin/master")
    end

    it "maps the remote's heads/* to a different local ref" do
      jit_cmd "fetch", "origin", "refs/heads/*:refs/remotes/other/prefix-*"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/remotes/other/prefix-master")
    end

    it "accepts short-hand refs in the fetch refspec" do
      jit_cmd "fetch", "origin", "master:topic"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/heads/topic")
    end

    it "accepts short-hand head refs in the fetch refspec" do
      jit_cmd "fetch", "origin", "master:heads/topic"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/heads/topic")
    end

    it "accepts short-hand remote refs in the fetch refspec" do
      jit_cmd "fetch", "origin", "master:remotes/topic"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/remotes/topic")
    end

    it "does not create any other local refs" do
      jit_cmd "fetch"

      assert_equal ["HEAD", "refs/remotes/origin/master"],
                   repo.refs.list_all_refs.map(&:path).sort
    end

    it "retrieves all the commits from the remote's history" do
      jit_cmd "fetch"

      assert_equal commits(@remote.repo, ["master"]),
                   commits(repo, ["origin/master"])
    end

    it "retrieves enough information to check out the remote's commits" do
      jit_cmd "fetch"

      jit_cmd "checkout", "origin/master^"
      assert_workspace "one.txt" => "one", "dir/two.txt" => "dir/two"

      jit_cmd "checkout", "origin/master"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "three.txt"   => "three"

      jit_cmd "checkout", "origin/master^^"
      assert_workspace "one.txt" => "one"
    end

    describe "when an unpack limit is set" do
      before do
        jit_cmd "config", "fetch.unpackLimit", "5"
      end

      it "keeps the pack on disk with an index" do
        jit_cmd "fetch"
        assert_object_count 2
      end

      it "can load commits from the stored pack" do
        jit_cmd "fetch"

        assert_equal commits(@remote.repo, ["master"]),
                     commits(repo, ["origin/master"])
      end
    end

    describe "when the remote ref is ahead of its local counterpart" do
      before do
        jit_cmd "fetch"

        @remote.write_file "one.txt", "changed"
        @remote.jit_cmd "add", "."
        @remote.jit_cmd "commit", "-m", "changed"

        @local_head  = commits(repo, ["origin/master"]).first
        @remote_head = commits(@remote.repo, ["master"]).first
      end

      it "displays a fast-forward on the changed branch" do
        jit_cmd "fetch"
        assert_status 0

        assert_stderr <<~OUTPUT
          From file://#{ @remote.repo_path }
             #{ @local_head }..#{ @remote_head } master -> origin/master
        OUTPUT
      end
    end

    describe "when the remote ref has diverged from its local counterpart" do
      before do
        jit_cmd "fetch"

        @remote.write_file "one.txt", "changed"
        @remote.jit_cmd "add", "."
        @remote.jit_cmd "commit", "--amend"

        @local_head  = commits(repo, ["origin/master"]).first
        @remote_head = commits(@remote.repo, ["master"]).first
      end

      it "displays a forced update on the changed branch" do
        jit_cmd "fetch"
        assert_status 0

        assert_stderr <<~OUTPUT
          From file://#{ @remote.repo_path }
           + #{ @local_head }...#{ @remote_head } master -> origin/master (forced update)
        OUTPUT
      end

      it "displays a forced update if requested" do
        jit_cmd "fetch", "-f", "origin", "refs/heads/*:refs/remotes/origin/*"
        assert_status 0

        assert_stderr <<~OUTPUT
          From file://#{ @remote.repo_path }
           + #{ @local_head }...#{ @remote_head } master -> origin/master (forced update)
        OUTPUT
      end

      it "updates the local remotes/origin/* ref" do
        jit_cmd "fetch"

        refute_equal @remote_head, @local_head
        assert_equal @remote_head, commits(repo, ["origin/master"]).first
      end

      describe "if a fetch is not forced" do
        before do
          jit_cmd "fetch", "origin", "refs/heads/*:refs/remotes/origin/*"
        end

        it "exits with an error" do
          assert_status 1
        end

        it "displays a rejection" do
          assert_stderr <<~OUTPUT
            From file://#{ @remote.repo_path }
             ! [rejected] master -> origin/master (non-fast-forward)
          OUTPUT
        end

        it "does not update the local remotes/origin/* ref" do
          refute_equal @remote_head, @local_head
          assert_equal @local_head, commits(repo, ["origin/master"]).first
        end
      end
    end
  end

  describe "with multiple branches in the remote repository" do
    before do
      @remote = RemoteRepo.new("fetch-remote")
      @remote.jit_cmd "init", @remote.repo_path.to_s

      ["one", "dir/two", "three"].each { |msg| write_commit msg }

      @remote.jit_cmd "branch", "topic", "@^"
      @remote.jit_cmd "checkout", "topic"
      write_commit "four"

      jit_cmd "remote", "add", "origin", "file://#{ @remote.repo_path }"
      jit_cmd "config", "remote.origin.uploadpack", "#{ jit_path } upload-pack"
    end

    after do
      FileUtils.rm_rf(@remote.repo_path)
    end

    it "displays the new branches being fetched" do
      jit_cmd "fetch"
      assert_status 0

      assert_stderr <<~OUTPUT
        From file://#{ @remote.repo_path }
         * [new branch] master -> origin/master
         * [new branch] topic -> origin/topic
      OUTPUT
    end

    it "maps the remote's heads/* to the local's remotes/origin/*" do
      jit_cmd "fetch"

      remote_master = @remote.repo.refs.read_ref("refs/heads/master")
      remote_topic  = @remote.repo.refs.read_ref("refs/heads/topic")

      refute_equal remote_master, remote_topic
      assert_equal remote_master, repo.refs.read_ref("refs/remotes/origin/master")
      assert_equal remote_topic, repo.refs.read_ref("refs/remotes/origin/topic")
    end

    it "maps the remote's heads/* to a different local ref" do
      jit_cmd "fetch", "origin", "refs/heads/*:refs/remotes/other/prefix-*"

      assert_equal @remote.repo.refs.read_ref("refs/heads/master"),
                   repo.refs.read_ref("refs/remotes/other/prefix-master")

      assert_equal @remote.repo.refs.read_ref("refs/heads/topic"),
                   repo.refs.read_ref("refs/remotes/other/prefix-topic")
    end

    it "does not create any other local refs" do
      jit_cmd "fetch"

      assert_equal ["HEAD", "refs/remotes/origin/master", "refs/remotes/origin/topic"],
                   repo.refs.list_all_refs.map(&:path).sort
    end

    it "retrieves all the commits from the remote's history" do
      jit_cmd "fetch"
      assert_object_count 13

      remote_commits = commits(@remote.repo, [], :all => true)
      assert_equal 4, remote_commits.size

      assert_equal remote_commits, commits(repo, [], :all => true)
    end

    it "retrieves enough information to check out the remote's commits" do
      jit_cmd "fetch"

      jit_cmd "checkout", "origin/master"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "three.txt"   => "three"

      jit_cmd "checkout", "origin/topic"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "four.txt"    => "four"
    end

    describe "when a specific branch is requested" do
      before do
        jit_cmd "fetch", "origin", "+refs/heads/*ic:refs/remotes/origin/*"
      end

      it "displays the branch being fetched" do
        assert_stderr <<~OUTPUT
          From file://#{ @remote.repo_path }
           * [new branch] topic -> origin/top
        OUTPUT
      end

      it "does not create any other local refs" do
        assert_equal ["HEAD", "refs/remotes/origin/top"],
                     repo.refs.list_all_refs.map(&:path).sort
      end

      it "retrieves only the commits from the fetched branch" do
        assert_object_count 10

        remote_commits = commits(@remote.repo, ["topic"])
        assert_equal 3, remote_commits.size

        assert_equal remote_commits, commits(repo, [], :all => true)
      end
    end
  end
end
