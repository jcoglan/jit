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
    set_stdin "M"
    jit_cmd "merge", "topic"
  end

  def assert_clean_merge
    jit_cmd "status", "--porcelain"
    assert_stdout ""

    commit     = load_commit("@")
    old_head   = load_commit("@^")
    merge_head = load_commit("topic")

    assert_equal "M", commit.message
    assert_equal [old_head.oid, merge_head.oid], commit.parents
  end

  def assert_no_merge
    commit = load_commit("@")
    assert_equal "B", commit.message
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
      assert_equal "C", commit.message

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

      set_stdin "M"
      jit_cmd "merge", "master"
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
      assert_equal "C", commit.message

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
      set_stdin "merge joiner"
      jit_cmd "merge", "joiner"
      assert_status 0

      assert_workspace \
        "f.txt" => "3",
        "g.txt" => "2",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end

    it "performs the second merge" do
      set_stdin "merge joiner"
      jit_cmd "merge", "joiner"

      commit_tree "H", "f.txt" => "4"

      set_stdin "merge topic"
      jit_cmd "merge", "topic"
      assert_status 0

      assert_workspace \
        "f.txt" => "4",
        "g.txt" => "3",
        "h.txt" => "1"

      jit_cmd "status", "--porcelain"
      assert_stdout ""
    end
  end
end
