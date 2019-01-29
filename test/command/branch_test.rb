require "minitest/autorun"
require "command_helper"

describe Command::Branch do
  include CommandHelper

  def write_commit(message)
    write_file "file.txt", message
    jit_cmd "add", "."
    commit message
  end

  describe "with a chain of commits" do
    before do
      ["first", "second", "third"].each { |msg| write_commit msg }
    end

    it "creates a branch pointing at HEAD" do
      jit_cmd "branch", "topic"

      assert_equal repo.refs.read_head,
                   repo.refs.read_ref("topic")
    end

    it "fails for invalid branch names" do
      jit_cmd "branch", "^"

      assert_stderr <<~ERROR
        fatal: '^' is not a valid branch name.
      ERROR
    end

    it "fails for existing branch names" do
      jit_cmd "branch", "topic"
      jit_cmd "branch", "topic"

      assert_stderr <<~ERROR
        fatal: A branch named 'topic' already exists.
      ERROR
    end

    it "creates a branch pointing at HEAD's parent" do
      jit_cmd "branch", "topic", "HEAD^"

      head = repo.database.load(repo.refs.read_head)

      assert_equal head.parent,
                   repo.refs.read_ref("topic")
    end

    it "creates a branch pointing at HEAD's grandparent" do
      jit_cmd "branch", "topic", "@~2"

      head   = repo.database.load(repo.refs.read_head)
      parent = repo.database.load(head.parent)

      assert_equal parent.parent,
                   repo.refs.read_ref("topic")
    end

    it "creates a branch relative to another one" do
      jit_cmd "branch", "topic", "@~1"
      jit_cmd "branch", "another", "topic^"

      assert_equal resolve_revision("HEAD~2"),
                   repo.refs.read_ref("another")
    end

    it "creates a branch from a short commit ID" do
      commit_id = resolve_revision("@~2")
      jit_cmd "branch", "topic", repo.database.short_oid(commit_id)

      assert_equal commit_id,
                   repo.refs.read_ref("topic")
    end

    it "fails for invalid revisions" do
      jit_cmd "branch", "topic", "^"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '^'.
      ERROR
    end

    it "fails for invalid refs" do
      jit_cmd "branch", "topic", "no-such-branch"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: 'no-such-branch'.
      ERROR
    end

    it "fails for invalid parents" do
      jit_cmd "branch", "topic", "@^^^^"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '@^^^^'.
      ERROR
    end

    it "fails for invalid ancestors" do
      jit_cmd "branch", "topic", "@~50"

      assert_stderr <<~ERROR
        fatal: Not a valid object name: '@~50'.
      ERROR
    end

    it "fails for revisions that are not commits" do
      tree_id = repo.database.load(repo.refs.read_head).tree
      jit_cmd "branch", "topic", tree_id

      assert_stderr <<~ERROR
        error: object #{ tree_id } is a tree, not a commit
        fatal: Not a valid object name: '#{ tree_id }'.
      ERROR
    end

    it "fails for parents of revisions that are not commits" do
      tree_id = repo.database.load(repo.refs.read_head).tree
      jit_cmd "branch", "topic", "#{ tree_id }^^"

      assert_stderr <<~ERROR
        error: object #{ tree_id } is a tree, not a commit
        fatal: Not a valid object name: '#{ tree_id }^^'.
      ERROR
    end

    it "lists existing branches" do
      jit_cmd "branch", "new-feature"
      jit_cmd "branch"

      assert_stdout <<~BRANCH
        * master
          new-feature
      BRANCH
    end

    it "lists existing branches with verbose info" do
      a = load_commit("@^")
      b = load_commit("@")

      jit_cmd "branch", "new-feature", "@^"
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master      #{ repo.database.short_oid(b.oid) } third
          new-feature #{ repo.database.short_oid(a.oid) } second
      BRANCH
    end

    it "deletes a branch" do
      head = repo.refs.read_head

      jit_cmd "branch", "bug-fix"
      jit_cmd "branch", "--delete", "bug-fix"

      assert_stdout <<~MSG
        Deleted branch bug-fix (was #{ repo.database.short_oid(head) }).
      MSG

      branches = repo.refs.list_branches
      refute_includes branches.map(&:short_name), "bug-fix"
    end

    it "fails to delete a non-existent branch" do
      jit_cmd "branch", "--delete", "no-such-branch"

      assert_status 1

      assert_stderr <<~ERROR
        error: branch 'no-such-branch' not found.
      ERROR
    end

    describe "when the branch has diverged" do
      before do
        jit_cmd "branch", "topic"
        jit_cmd "checkout", "topic"

        write_commit "changed"

        jit_cmd "checkout", "master"
      end

      it "deletes a merged branch" do
        head = repo.refs.read_head

        jit_cmd "checkout", "topic"
        jit_cmd "branch", "--delete", "master"
        assert_status 0

        assert_stdout <<~MSG
          Deleted branch master (was #{ repo.database.short_oid(head) }).
        MSG
      end

      it "refuses to delete the branch" do
        jit_cmd "branch", "--delete", "topic"
        assert_status 1

        assert_stderr <<~ERROR
          error: The branch 'topic' is not fully merged.
        ERROR
      end

      it "deletes the branch with force" do
        head = repo.refs.read_ref("topic")

        jit_cmd "branch", "-D", "topic"
        assert_status 0

        assert_stdout <<~MSG
          Deleted branch topic (was #{ repo.database.short_oid(head) }).
        MSG
      end
    end
  end

  describe "tracking remote branches" do
    before do
      jit_cmd "remote", "add", "origin", "ssh://example.com/repo"
      @upstream = "refs/remotes/origin/master"

      ["first", "second", "remote"].each { |msg| write_commit msg }
      repo.refs.update_ref(@upstream, repo.refs.read_head)

      jit_cmd "reset", "--hard", "@^"
      ["third", "local"].each { |msg| write_commit msg }

      @head   = repo.database.short_oid(repo.refs.read_head)
      @remote = repo.database.short_oid(repo.refs.read_ref(@upstream))
    end

    it "displays no divergence for unlinked branches" do
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master #{ @head } local
      BRANCH
    end

    it "displays divergence for linked branches" do
      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master #{ @head } [ahead 2, behind 1] local
      BRANCH
    end

    it "displays the branch ahead of its upstream" do
      repo.refs.update_ref(@upstream, resolve_revision("master~2"))

      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master #{ @head } [ahead 2] local
      BRANCH
    end

    it "displays the branch behind its upstream" do
      master = resolve_revision("@~2")
      oid    = repo.database.short_oid(master)

      jit_cmd "reset", master
      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master #{ oid } [behind 1] second
      BRANCH
    end

    it "displays the upstream branch name" do
      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "-vv"

      assert_stdout <<~BRANCH
        * master #{ @head } [origin/master, ahead 2, behind 1] local
      BRANCH
    end

    it "displays the upstream branch name with no divergence" do
      jit_cmd "reset", "--hard", "origin/master"

      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "-vv"

      assert_stdout <<~BRANCH
        * master #{ @remote } [origin/master] remote
      BRANCH
    end

    it "fails if the upstream ref does not exist" do
      jit_cmd "branch", "--set-upstream-to", "origin/nope"
      assert_status 1

      assert_stderr <<~ERROR
        error: the requested upstream branch 'origin/nope' does not exist
      ERROR
    end

    it "fails if the upstream remote does not exist" do
      repo.refs.update_ref("refs/remotes/nope/master", repo.refs.read_head)

      jit_cmd "branch", "--set-upstream-to", "nope/master"
      assert_status 128

      assert_stderr \
        "fatal: Cannot setup tracking information; " +
        "starting point 'refs/remotes/nope/master' is not a branch\n"
    end

    it "creates a branch tracking its start point" do
      jit_cmd "branch", "--track", "topic", "origin/master"
      jit_cmd "checkout", "topic"

      write_commit "topic"
      oid = repo.database.short_oid(repo.refs.read_head)

      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        master #{ @head } local
      * topic  #{   oid } [ahead 1] topic
      BRANCH
    end

    it "unlinks a branch from its upstream" do
      jit_cmd "branch", "--set-upstream-to", "origin/master"
      jit_cmd "branch", "--unset-upstream"
      jit_cmd "branch", "--verbose"

      assert_stdout <<~BRANCH
        * master #{ @head } local
      BRANCH
    end
  end
end
