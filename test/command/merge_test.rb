require "minitest/autorun"
require "command_helper"

describe Command::Merge do
  include CommandHelper

  def commit_tree(message, files)
    files.each do |path, contents|
      delete(path) unless contents == :x
      case contents
      when String then write_file(path, contents)
      when :x     then make_executable(path)
      when Array
        write_file(path, contents[0])
        make_executable(path)
      end
    end
    delete ".git/index"
    jit_cmd "add", "."
    commit message
  end

  #   A   B   M
  #   o---o---o [master]
  #    \     /
  #     `---o [topic]
  #         C
  #
  def merge3(base, left, right)
    commit_tree "A", base
    commit_tree "B", left

    jit_cmd "branch", "topic", "master^"
    jit_cmd "checkout", "topic"
    commit_tree "C", right

    jit_cmd "checkout", "master"
    jit_cmd "merge", "topic", "-m", "M"
  end

  def assert_clean_merge
    jit_cmd "status", "--porcelain"
    assert_stdout ""

    commit     = load_commit("@")
    old_head   = load_commit("@^")
    merge_head = load_commit("topic")

    assert_equal "M", commit.message.strip
    assert_equal [old_head.oid, merge_head.oid], commit.parents
  end

  def assert_no_merge
    commit = load_commit("@")
    assert_equal "B", commit.message.strip
    assert_equal 1, commit.parents.size
  end

  def assert_index(*entries)
    repo.index.load
    actual = repo.index.each_entry.map { |e| [e.path, e.stage] }
    assert_equal entries, actual
  end

  describe "merging an ancestor" do
    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "merge", "@^"
    end

    it "prints the up-to-date message" do
      assert_stdout "Already up to date.\n"
    end

    it "does not change the repository state" do
      commit = load_commit("@")
      assert_equal "C", commit.message.strip

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end

  describe "fast-forward merge" do
    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "branch", "topic", "@^^"
      jit_cmd "checkout", "topic"
      jit_cmd "merge", "master", "-m", "M"
    end

    it "prints the fast-forward message" do
      a, b = ["master^^", "master"].map { |rev| resolve_revision(rev) }
      assert_stdout <<~MSG
        Updating #{ repo.database.short_oid(a) }..#{ repo.database.short_oid(b) }
        Fast-forward
      MSG
    end

    it "updates the current branch HEAD" do
      commit = load_commit("@")
      assert_equal "C", commit.message.strip

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end

  describe "unconflicted merge with two files" do
    before do
      merge3(
        { "f.txt" => "1", "g.txt" => "1" },
        { "f.txt" => "2"                 },
        {                 "g.txt" => "2" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace \
        "f.txt" => "2",
        "g.txt" => "2"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge with a deleted file" do
    before do
      merge3(
        { "f.txt" => "1", "g.txt" => "1" },
        { "f.txt" => "2"                 },
        {                 "g.txt" => nil })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "2"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: same addition on both sides" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "g.txt" => "2" },
        { "g.txt" => "2" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace \
        "f.txt" => "1",
        "g.txt" => "2"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: same edit on both sides" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "f.txt" => "2" },
        { "f.txt" => "2" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "2"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: in-file merge possible" do
    before do
      merge3(
        { "f.txt" => "1\n2\n3\n" },
        { "f.txt" => "4\n2\n3\n" },
        { "f.txt" => "1\n2\n5\n" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "4\n2\n5\n"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: edit and mode-change" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "f.txt" => "2" },
        { "f.txt" => :x  })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "2"
      assert_executable "f.txt"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: mode-change and edit" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "f.txt" => :x  },
        { "f.txt" => "3" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "3"
      assert_executable "f.txt"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: same deletion on both sides" do
    before do
      merge3(
        { "f.txt" => "1", "g.txt" => "1" },
        {                 "g.txt" => nil },
        {                 "g.txt" => nil })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "f.txt" => "1"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: delete-add-parent" do
    before do
      merge3(
        { "nest/f.txt" => "1" },
        { "nest/f.txt" => nil },
        { "nest"       => "3" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "nest" => "3"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "unconflicted merge: delete-add-child" do
    before do
      merge3(
        { "nest/f.txt" => "1" },
        { "nest/f.txt" => nil },
        { "nest/f.txt" => nil, "nest/f.txt/g.txt" => "3" })
    end

    it "puts the combined changes in the workspace" do
      assert_workspace "nest/f.txt/g.txt" => "3"
    end

    it "creates a clean merge" do
      assert_clean_merge
    end
  end

  describe "conflicted merge: add-add" do
    before do
      merge3(
        { "f.txt" => "1"   },
        { "g.txt" => "2\n" },
        { "g.txt" => "3\n" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Auto-merging g.txt
        CONFLICT (add/add): Merge conflict in g.txt
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts the conflicted file in the workspace" do
      assert_workspace \
        "f.txt" => "1",
        "g.txt" => <<~FILE
          <<<<<<< HEAD
          2
          =======
          3
          >>>>>>> topic
        FILE
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 0],
        ["g.txt", 2],
        ["g.txt", 3]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        AA g.txt
      STATUS
    end

    it "shows the combined diff against stages 2 and 3" do
      jit_cmd "diff"

      assert_stdout <<~DIFF
        diff --cc g.txt
        index 0cfbf08,00750ed..2603ab2
        --- a/g.txt
        +++ b/g.txt
        @@@ -1,1 -1,1 +1,5 @@@
        ++<<<<<<< HEAD
         +2
        ++=======
        + 3
        ++>>>>>>> topic
      DIFF
    end

    it "shows the diff against our version" do
      jit_cmd "diff", "--ours"

      assert_stdout <<~DIFF
        * Unmerged path g.txt
        diff --git a/g.txt b/g.txt
        index 0cfbf08..2603ab2 100644
        --- a/g.txt
        +++ b/g.txt
        @@ -1,1 +1,5 @@
        +<<<<<<< HEAD
         2
        +=======
        +3
        +>>>>>>> topic
      DIFF
    end

    it "shows the diff against their version" do
      jit_cmd "diff", "--theirs"

      assert_stdout <<~DIFF
        * Unmerged path g.txt
        diff --git a/g.txt b/g.txt
        index 00750ed..2603ab2 100644
        --- a/g.txt
        +++ b/g.txt
        @@ -1,1 +1,5 @@
        +<<<<<<< HEAD
        +2
        +=======
         3
        +>>>>>>> topic
      DIFF
    end
  end

  describe "conflicted merge: add-add mode conflict" do
    before do
      merge3(
        { "f.txt" => "1"   },
        { "g.txt" => "2"   },
        { "g.txt" => ["2"] })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Auto-merging g.txt
        CONFLICT (add/add): Merge conflict in g.txt
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts the conflicted file in the workspace" do
      assert_workspace \
        "f.txt" => "1",
        "g.txt" => "2"
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 0],
        ["g.txt", 2],
        ["g.txt", 3]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        AA g.txt
      STATUS
    end

    it "shows the combined diff against stages 2 and 3" do
      jit_cmd "diff"

      assert_stdout <<~DIFF
        diff --cc g.txt
        index d8263ee,d8263ee..d8263ee
        mode 100644,100755..100644
        --- a/g.txt
        +++ b/g.txt
      DIFF
    end

    it "reports the mode change in the appropriate diff" do
      jit_cmd "diff", "-2"
      assert_stdout <<~DIFF
        * Unmerged path g.txt
      DIFF

      jit_cmd "diff", "-3"
      assert_stdout <<~DIFF
        * Unmerged path g.txt
        diff --git a/g.txt b/g.txt
        old mode 100755
        new mode 100644
      DIFF
    end
  end

  describe "conflicted merge: file/directory addition" do
    before do
      merge3(
        { "f.txt"            => "1" },
        { "g.txt"            => "2" },
        { "g.txt/nested.txt" => "3" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Adding g.txt/nested.txt
        CONFLICT (file/directory): There is a directory with name g.txt in topic. Adding g.txt as g.txt~HEAD
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts a namespaced copy of the conflicted file in the workspace" do
      assert_workspace \
        "f.txt"            => "1",
        "g.txt~HEAD"       => "2",
        "g.txt/nested.txt" => "3"
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 0],
        ["g.txt", 2],
        ["g.txt/nested.txt", 0]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        AU g.txt
        A  g.txt/nested.txt
        ?? g.txt~HEAD
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"
      assert_stdout "* Unmerged path g.txt\n"
    end
  end

  describe "conflicted merge: directory/file addition" do
    before do
      merge3(
        { "f.txt"            => "1" },
        { "g.txt/nested.txt" => "2" },
        { "g.txt"            => "3" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Adding g.txt/nested.txt
        CONFLICT (directory/file): There is a directory with name g.txt in HEAD. Adding g.txt as g.txt~topic
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts a namespaced copy of the conflicted file in the workspace" do
      assert_workspace \
        "f.txt"            => "1",
        "g.txt~topic"      => "3",
        "g.txt/nested.txt" => "2"
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 0],
        ["g.txt", 3],
        ["g.txt/nested.txt", 0]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UA g.txt
        ?? g.txt~topic
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"
      assert_stdout "* Unmerged path g.txt\n"
    end
  end

  describe "conflicted merge: edit-edit" do
    before do
      merge3(
        { "f.txt" => "1\n" },
        { "f.txt" => "2\n" },
        { "f.txt" => "3\n" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Auto-merging f.txt
        CONFLICT (content): Merge conflict in f.txt
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts the conflicted file in the workspace" do
      assert_workspace \
        "f.txt" => <<~FILE
          <<<<<<< HEAD
          2
          =======
          3
          >>>>>>> topic
        FILE
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 1],
        ["f.txt", 2],
        ["f.txt", 3]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UU f.txt
      STATUS
    end

    it "shows the combined diff against stages 2 and 3" do
      jit_cmd "diff"

      assert_stdout <<~DIFF
        diff --cc f.txt
        index 0cfbf08,00750ed..2603ab2
        --- a/f.txt
        +++ b/f.txt
        @@@ -1,1 -1,1 +1,5 @@@
        ++<<<<<<< HEAD
         +2
        ++=======
        + 3
        ++>>>>>>> topic
      DIFF
    end
  end

  describe "conflicted merge: edit-delete" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "f.txt" => "2" },
        { "f.txt" => nil })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        CONFLICT (modify/delete): f.txt deleted in topic and modified in HEAD. Version HEAD of f.txt left in tree.
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts the left version in the workspace" do
      assert_workspace "f.txt" => "2"
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 1],
        ["f.txt", 2]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UD f.txt
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"
      assert_stdout "* Unmerged path f.txt\n"
    end
  end

  describe "conflicted merge: delete-edit" do
    before do
      merge3(
        { "f.txt" => "1" },
        { "f.txt" => nil },
        { "f.txt" => "3" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        CONFLICT (modify/delete): f.txt deleted in HEAD and modified in topic. Version topic of f.txt left in tree.
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts the right version in the workspace" do
      assert_workspace "f.txt" => "3"
    end

    it "records the conflict in the index" do
      assert_index \
        ["f.txt", 1],
        ["f.txt", 3]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        DU f.txt
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"
      assert_stdout "* Unmerged path f.txt\n"
    end
  end

  describe "conflicted merge: edit-add-parent" do
    before do
      merge3(
        { "nest/f.txt" => "1" },
        { "nest/f.txt" => "2" },
        { "nest"       => "3" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        CONFLICT (modify/delete): nest/f.txt deleted in topic and modified in HEAD. Version HEAD of nest/f.txt left in tree.
        CONFLICT (directory/file): There is a directory with name nest in HEAD. Adding nest as nest~topic
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts a namespaced copy of the conflicted file in the workspace" do
      assert_workspace \
        "nest/f.txt" => "2",
        "nest~topic" => "3"
    end

    it "records the conflict in the index" do
      assert_index \
        ["nest", 3],
        ["nest/f.txt", 1],
        ["nest/f.txt", 2]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UA nest
        UD nest/f.txt
        ?? nest~topic
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"

      assert_stdout <<~DIFF
        * Unmerged path nest
        * Unmerged path nest/f.txt
      DIFF
    end
  end

  describe "conflicted merge: edit-add-child" do
    before do
      merge3(
        { "nest/f.txt" => "1" },
        { "nest/f.txt" => "2" },
        { "nest/f.txt" => nil, "nest/f.txt/g.txt" => "3" })
    end

    it "prints the merge conflicts" do
      assert_stdout <<~MSG
        Adding nest/f.txt/g.txt
        CONFLICT (modify/delete): nest/f.txt deleted in topic and modified in HEAD. Version HEAD of nest/f.txt left in tree at nest/f.txt~HEAD.
        Automatic merge failed; fix conflicts and then commit the result.
      MSG
    end

    it "puts a namespaced copy of the conflicted file in the workspace" do
      assert_workspace \
        "nest/f.txt~HEAD"  => "2",
        "nest/f.txt/g.txt" => "3"
    end

    it "records the conflict in the index" do
      assert_index \
        ["nest/f.txt", 1], # missing
        ["nest/f.txt", 2],
        ["nest/f.txt/g.txt", 0]
    end

    it "does not write a merge commit" do
      assert_no_merge
    end

    it "reports the conflict in the status" do
      jit_cmd "status", "--porcelain"

      assert_stdout <<~STATUS
        UD nest/f.txt
        A  nest/f.txt/g.txt
        ?? nest/f.txt~HEAD
      STATUS
    end

    it "lists the file as unmerged in the diff" do
      jit_cmd "diff"
      assert_stdout "* Unmerged path nest/f.txt\n"
    end
  end

  describe "multiple common ancestors" do

    #   A   B   C       M1  H   M2
    #   o---o---o-------o---o---o
    #        \         /       /
    #         o---o---o G     /
    #         D  E \         /
    #               `-------o
    #                       F

    before do
      commit_tree "A", "f.txt" => "1"
      commit_tree "B", "f.txt" => "2"
      commit_tree "C", "f.txt" => "3"

      jit_cmd "branch", "topic", "master^"
      jit_cmd "checkout", "topic"
      commit_tree "D", "g.txt" => "1"
      commit_tree "E", "g.txt" => "2"
      commit_tree "F", "g.txt" => "3"

      jit_cmd "branch", "joiner", "topic^"
      jit_cmd "checkout", "joiner"
      commit_tree "G", "h.txt" => "1"

      jit_cmd "checkout", "master"
    end

    it "performs the first merge" do
      jit_cmd "merge", "joiner", "-m", "merge joiner"
      assert_status 0

      assert_workspace \
        "f.txt" => "3",
        "g.txt" => "2",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end

    it "performs the second merge" do
      jit_cmd "merge", "joiner", "-m", "merge joiner"
      commit_tree "H", "f.txt" => "4"

      jit_cmd "merge", "topic", "-m", "merge topic"
      assert_status 0

      assert_workspace \
        "f.txt" => "4",
        "g.txt" => "3",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end

  describe "conflict resolution" do
    before do
      merge3(
        { "f.txt" => "1\n" },
        { "f.txt" => "2\n" },
        { "f.txt" => "3\n" })
    end

    it "prevents commits with unmerged entries" do
      jit_cmd "commit"

      assert_stderr <<~ERROR
        error: Committing is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
      assert_status 128

      assert_equal "B", load_commit("@").message.strip
    end

    it "prevents merge --continue with unmerged entries" do
      jit_cmd "merge", "--continue"

      assert_stderr <<~ERROR
        error: Committing is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
      assert_status 128

      assert_equal "B", load_commit("@").message.strip
    end

    it "commits a merge after resolving conflicts" do
      jit_cmd "add", "f.txt"
      jit_cmd "commit"
      assert_status 0

      commit = load_commit("@")
      assert_equal "M", commit.message.strip

      parents = commit.parents.map { |oid| load_commit(oid).message.strip }
      assert_equal ["B", "C"], parents
    end

    it "allows merge --continue after resolving conflicts" do
      jit_cmd "add", "f.txt"
      jit_cmd "merge", "--continue"
      assert_status 0

      commit = load_commit("@")
      assert_equal "M", commit.message.strip

      parents = commit.parents.map { |oid| load_commit(oid).message.strip }
      assert_equal ["B", "C"], parents
    end

    it "prevents merge --continue when none is in progress" do
      jit_cmd "add", "f.txt"
      jit_cmd "merge", "--continue"
      jit_cmd "merge", "--continue"

      assert_stderr "fatal: There is no merge in progress (MERGE_HEAD missing).\n"
      assert_status 128
    end

    it "aborts the merge" do
      jit_cmd "merge", "--abort"
      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end

    it "prevents aborting a merge when none is in progress" do
      jit_cmd "merge", "--abort"
      jit_cmd "merge", "--abort"

      assert_stderr "fatal: There is no merge to abort (MERGE_HEAD missing).\n"
      assert_status 128
    end

    it "prevents starting a new merge while one is in progress" do
      jit_cmd "merge"

      assert_stderr <<~ERROR
        error: Merging is not possible because you have unmerged files.
        hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
        hint: as appropriate to mark resolution and make a commit.
        fatal: Exiting because of an unresolved conflict.
      ERROR
      assert_status 128
    end
  end
end
