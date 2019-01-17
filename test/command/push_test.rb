require "minitest/autorun"
require "fileutils"
require "find"

require "command_helper"
require "remote_repo"
require "rev_list"

ENV["NO_PROGRESS"] = "1"

describe Command::Push do
  include CommandHelper

  def create_remote_repo(name)
    RemoteRepo.new(name).tap do |repo|
      repo.jit_cmd "init", repo.repo_path.to_s
      repo.jit_cmd "config", "receive.denyCurrentBranch", "false"
      repo.jit_cmd "config", "receive.denyDeleteCurrent", "false"
    end
  end

  def write_commit(message)
    write_file "#{ message }.txt", message
    jit_cmd "add", "."
    jit_cmd "commit", "-m", message
  end

  def commits(repo, revs, options = {})
    RevList.new(repo, revs, options).map do |commit|
      repo.database.short_oid(commit.oid)
    end
  end

  def assert_object_count(n)
    count = 0
    Find.find(@remote.repo_path.join(".git", "objects")) do |path|
      count += 1 if File.file?(path)
    end
    assert_equal(n, count)
  end

  def assert_refs(repo, refs)
    assert_equal refs, repo.refs.list_all_refs.map(&:path).sort
  end

  def assert_workspace(contents)
    super(contents, @remote.repo)
  end

  def jit_path
    File.expand_path("../../../bin/jit", __FILE__)
  end

  describe "with a single branch in the local repository" do
    before do
      @remote = create_remote_repo("push-remote")

      ["one", "dir/two", "three"].each { |msg| write_commit msg }

      jit_cmd "remote", "add", "origin", "file://#{ @remote.repo_path }"
      jit_cmd "config", "remote.origin.receivepack", "#{ jit_path } receive-pack"
      jit_cmd "config", "remote.origin.uploadpack", "#{ jit_path } upload-pack"
    end

    after do
      FileUtils.rm_rf(@remote.repo_path)
    end

    it "displays a new branch being pushed" do
      jit_cmd "push", "origin", "master"
      assert_status 0

      assert_stderr <<~OUTPUT
        To file://#{ @remote.repo_path }
         * [new branch] master -> master
      OUTPUT
    end

    it "maps the locals's head to the remote's" do
      jit_cmd "push", "origin", "master"

      assert_equal repo.refs.read_ref("refs/heads/master"),
                   @remote.repo.refs.read_ref("refs/heads/master")
    end

    it "maps the locals's head to a different remote ref" do
      jit_cmd "push", "origin", "master:refs/heads/other"

      assert_equal repo.refs.read_ref("refs/heads/master"),
                   @remote.repo.refs.read_ref("refs/heads/other")
    end

    it "does not create any other remote refs" do
      jit_cmd "push", "origin", "master"

      assert_refs @remote.repo, ["HEAD", "refs/heads/master"]
    end

    it "sends all the commits from the locals's history" do
      jit_cmd "push", "origin", "master"

      assert_equal commits(repo, ["master"]),
                   commits(@remote.repo, ["master"])
    end

    it "sends enough information to check out the locals's commits" do
      jit_cmd "push", "origin", "master"

      @remote.jit_cmd "reset", "--hard"

      @remote.jit_cmd "checkout", "master^"
      assert_workspace "one.txt" => "one", "dir/two.txt" => "dir/two"

      @remote.jit_cmd "checkout", "master"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "three.txt"   => "three"

      @remote.jit_cmd "checkout", "master^^"
      assert_workspace "one.txt" => "one"
    end

    it "pushes an ancestor of the current HEAD" do
      jit_cmd "push", "origin", "@~1:master"

      assert_stderr <<~OUTPUT
        To file://#{ @remote.repo_path }
         * [new branch] @~1 -> master
      OUTPUT

      assert_equal commits(repo, ["master^"]),
                   commits(@remote.repo, ["master"])
    end

    describe "after a successful push" do
      before do
        jit_cmd "push", "origin", "master"
      end

      it "says everything is up to date" do
        jit_cmd "push", "origin", "master"
        assert_status 0

        assert_stderr <<~OUTPUT
          Everything up-to-date
        OUTPUT

        assert_refs @remote.repo, ["HEAD", "refs/heads/master"]

        assert_equal repo.refs.read_ref("refs/heads/master"),
                     @remote.repo.refs.read_ref("refs/heads/master")
      end

      it "deletes a remote branch by refspec" do
        jit_cmd "push", "origin", ":master"
        assert_status 0

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           - [deleted] master
        OUTPUT

        assert_refs repo, ["HEAD", "refs/heads/master"]
        assert_refs @remote.repo, ["HEAD"]
      end
    end

    describe "when the local ref is ahead of its remote counterpart" do
      before do
        jit_cmd "push", "origin", "master"

        write_file "one.txt", "changed"
        jit_cmd "add", "."
        jit_cmd "commit", "-m", "changed"

        @local_head  = commits(repo, ["master"]).first
        @remote_head = commits(@remote.repo, ["master"]).first
      end

      it "displays a fast-forward on the changed branch" do
        jit_cmd "push", "origin", "master"
        assert_status 0

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
             #{ @remote_head }..#{ @local_head } master -> master
        OUTPUT
      end

      it "succeeds when the remote denies non-fast-forward changes" do
        @remote.jit_cmd "config", "receive.denyNonFastForwards", "true"

        jit_cmd "push", "origin", "master"
        assert_status 0

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
             #{ @remote_head }..#{ @local_head } master -> master
        OUTPUT
      end
    end

    describe "when the remote ref has diverged from its local counterpart" do
      before do
        jit_cmd "push", "origin", "master"

        @remote.write_file "one.txt", "changed"
        @remote.jit_cmd "add", "."
        @remote.jit_cmd "commit", "--amend"

        @local_head  = commits(repo, ["master"]).first
        @remote_head = commits(@remote.repo, ["master"]).first
      end

      it "displays a forced update if requested" do
        jit_cmd "push", "origin", "master", "-f"
        assert_status 0

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           + #{ @remote_head }...#{ @local_head } master -> master (forced update)
        OUTPUT
      end

      it "updates the local remotes/origin/* ref" do
        jit_cmd "push", "origin", "master", "-f"
        assert_equal @local_head, commits(repo, ["origin/master"]).first
      end

      it "deletes a remote branch by refspec" do
        jit_cmd "push", "origin", ":master"
        assert_status 0

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           - [deleted] master
        OUTPUT

        assert_refs repo, ["HEAD", "refs/heads/master"]
        assert_refs @remote.repo, ["HEAD"]
      end

      describe "if a push is not forced" do
        before do
          jit_cmd "push", "origin", "master"
        end

        it "exits with an error" do
          assert_status 1
        end

        it "tells the user to fetch before pushing" do
          assert_stderr <<~OUTPUT
            To file://#{ @remote.repo_path }
             ! [rejected] master -> master (fetch first)
          OUTPUT
        end

        it "displays a rejection after fetching" do
          jit_cmd "fetch"
          jit_cmd "push", "origin", "master"

          assert_stderr <<~OUTPUT
            To file://#{ @remote.repo_path }
             ! [rejected] master -> master (non-fast-forward)
          OUTPUT
        end

        it "does not update the local remotes/origin/* ref" do
          refute_equal @remote_head, @local_head
          assert_equal @local_head, commits(repo, ["origin/master"]).first
        end
      end

      describe "when the remote denies non-fast-forward updates" do
        before do
          @remote.jit_cmd "config", "receive.denyNonFastForwards", "true"
          jit_cmd "fetch"
        end

        it "rejects the pushed update" do
          jit_cmd "push", "origin", "master", "-f"
          assert_status 1

          assert_stderr <<~OUTPUT
            To file://#{ @remote.repo_path }
             ! [rejected] master -> master (non-fast-forward)
          OUTPUT
        end
      end
    end

    describe "when the remote denies updating the current branch" do
      before do
        @remote.jit_cmd "config", "--unset", "receive.denyCurrentBranch"
      end

      it "rejects the pushed update" do
        jit_cmd "push", "origin", "master"
        assert_status 1

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           ! [rejected] master -> master (branch is currently checked out)
        OUTPUT
      end

      it "does not update the remote's ref" do
        jit_cmd "push", "origin", "master"

        refute_nil repo.refs.read_ref("refs/heads/master")
        assert_nil @remote.repo.refs.read_ref("refs/heads/master")
      end

      it "does not update the local remotes/origin/* ref" do
        jit_cmd "push", "origin", "master"

        assert_nil repo.refs.read_ref("refs/remotes/origin/master")
      end
    end

    describe "when the remote denies deleting the current branch" do
      before do
        jit_cmd "push", "origin", "master"
        @remote.jit_cmd "config", "--unset", "receive.denyDeleteCurrent"
      end

      it "rejects the pushed update" do
        jit_cmd "push", "origin", ":master"
        assert_status 1

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           ! [rejected] master (deletion of the current branch prohibited)
        OUTPUT
      end

      it "does not delete the remote's ref" do
        jit_cmd "push", "origin", ":master"

        refute_nil @remote.repo.refs.read_ref("refs/heads/master")
      end

      it "does not delete the local remotes/origin/* ref" do
        jit_cmd "push", "origin", "master"

        refute_nil repo.refs.read_ref("refs/remotes/origin/master")
      end
    end

    describe "when the remote denies deleting any branch" do
      before do
        jit_cmd "push", "origin", "master"
        @remote.jit_cmd "config", "receive.denyDeletes", "true"
      end

      it "rejects the pushed update" do
        jit_cmd "push", "origin", ":master"
        assert_status 1

        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           ! [rejected] master (deletion prohibited)
        OUTPUT
      end

      it "does not delete the remote's ref" do
        jit_cmd "push", "origin", ":master"

        refute_nil @remote.repo.refs.read_ref("refs/heads/master")
      end

      it "does not delete the local remotes/origin/* ref" do
        jit_cmd "push", "origin", "master"

        refute_nil repo.refs.read_ref("refs/remotes/origin/master")
      end
    end
  end

  describe "with multiple branches in the local repository" do
    before do
      @remote = create_remote_repo("push-remote")

      ["one", "dir/two", "three"].each { |msg| write_commit msg }

      jit_cmd "branch", "topic", "@^"
      jit_cmd "checkout", "topic"
      write_commit "four"

      jit_cmd "remote", "add", "origin", "file://#{ @remote.repo_path }"
      jit_cmd "config", "remote.origin.receivepack", "#{ jit_path } receive-pack"
    end

    after do
      FileUtils.rm_rf(@remote.repo_path)
    end

    it "displays the new branches being pushed" do
      jit_cmd "push", "origin", "refs/heads/*"
      assert_status 0

      assert_stderr <<~OUTPUT
        To file://#{ @remote.repo_path }
         * [new branch] master -> master
         * [new branch] topic -> topic
      OUTPUT
    end

    it "maps the locals's heads/* to the remotes's heads/*" do
      jit_cmd "push", "origin", "refs/heads/*"

      local_master = repo.refs.read_ref("refs/heads/master")
      local_topic  = repo.refs.read_ref("refs/heads/topic")

      refute_equal local_master, local_topic
      assert_equal local_master, @remote.repo.refs.read_ref("refs/heads/master")
      assert_equal local_topic, @remote.repo.refs.read_ref("refs/heads/topic")
    end

    it "maps the local's heads/* to a different remote ref" do
      jit_cmd "push", "origin", "refs/heads/*:refs/other/*"

      assert_equal repo.refs.read_ref("refs/heads/master"),
                   @remote.repo.refs.read_ref("refs/other/master")

      assert_equal repo.refs.read_ref("refs/heads/topic"),
                   @remote.repo.refs.read_ref("refs/other/topic")
    end

    it "does not create any other remote refs" do
      jit_cmd "push", "origin", "refs/heads/*"

      assert_refs @remote.repo, ["HEAD", "refs/heads/master", "refs/heads/topic"]
    end

    it "sends all the commits from the local's history" do
      jit_cmd "push", "origin", "refs/heads/*"
      assert_object_count 13

      local_commits = commits(repo, ["master", "topic"])
      assert_equal 4, local_commits.size

      assert_equal local_commits, commits(@remote.repo, ["master", "topic"])
    end

    it "sends enough information to check out the locals's commits" do
      jit_cmd "push", "origin", "refs/heads/*"

      @remote.jit_cmd "reset", "--hard"

      @remote.jit_cmd "checkout", "master"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "three.txt"   => "three"

      @remote.jit_cmd "checkout", "topic"
      assert_workspace \
        "one.txt"     => "one",
        "dir/two.txt" => "dir/two",
        "four.txt"    => "four"
    end

    describe "when a specific branch is pushed" do
      before do
        jit_cmd "push", "origin", "refs/heads/*ic:refs/heads/*"
      end

      it "displays the branch being pushed" do
        assert_stderr <<~OUTPUT
          To file://#{ @remote.repo_path }
           * [new branch] topic -> top
        OUTPUT
      end

      it "does not create any other local refs" do
        assert_refs @remote.repo, ["HEAD", "refs/heads/top"]
      end

      it "retrieves only the commits from the fetched branch" do
        assert_object_count 10

        local_commits = commits(repo, ["topic"])
        assert_equal 3, local_commits.size

        assert_equal local_commits, commits(@remote.repo, [], :all => true)
      end
    end
  end

  describe "when the receiver has stored a pack" do
    before do
      @alice = create_remote_repo("push-remote-alice")
      @bob   = create_remote_repo("push-remote-bob")

      @alice.jit_cmd "config", "receive.unpackLimit", "5"

      ["one", "dir/two", "three"].each { |msg| write_commit msg }

      jit_cmd "remote", "add", "alice", "file://#{ @alice.repo_path }"
      jit_cmd "config", "remote.alice.receivepack", "#{ jit_path } receive-pack"

      jit_cmd "push", "alice", "refs/heads/*"
    end

    after do
      FileUtils.rm_rf(@alice.repo_path)
      FileUtils.rm_rf(@bob.repo_path)
    end

    it "can push packed objects to another repository" do
      @alice.jit_cmd "remote", "add", "bob", "file://#{ @bob.repo_path }"
      @alice.jit_cmd "config", "remote.bob.receivepack", "#{ jit_path } receive-pack"

      @alice.jit_cmd "push", "bob", "refs/heads/*"

      assert_equal commits(repo, ["master"]),
                   commits(@bob.repo, ["master"])
    end
  end
end
