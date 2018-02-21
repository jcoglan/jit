require "minitest/autorun"
require "command_helper"

describe Command::Diff do
  include CommandHelper

  def assert_diff(output)
    jit_cmd "diff"
    assert_stdout(output)
  end

  def assert_diff_cached(output)
    jit_cmd "diff", "--cached"
    assert_stdout(output)
  end

  describe "with a file in the index" do
    before do
      write_file "file.txt", <<~FILE
        contents
      FILE
      jit_cmd "add", "."
    end

    it "diffs a file with modified contents" do
      write_file "file.txt", <<~FILE
        changed
      FILE

      assert_diff <<~DIFF
        diff --git a/file.txt b/file.txt
        index 12f00e9..5ea2ed4 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -contents
        +changed
      DIFF
    end

    it "diffs a file with changed mode" do
      make_executable "file.txt"

      assert_diff <<~DIFF
        diff --git a/file.txt b/file.txt
        old mode 100644
        new mode 100755
      DIFF
    end

    it "diffs a file with changed mode and contents" do
      make_executable "file.txt"

      write_file "file.txt", <<~FILE
        changed
      FILE

      assert_diff <<~DIFF
        diff --git a/file.txt b/file.txt
        old mode 100644
        new mode 100755
        index 12f00e9..5ea2ed4
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -contents
        +changed
      DIFF
    end

    it "diffs a deleted file" do
      delete "file.txt"

      assert_diff <<~DIFF
        diff --git a/file.txt b/file.txt
        deleted file mode 100644
        index 12f00e9..0000000
        --- a/file.txt
        +++ /dev/null
        @@ -1,1 +0,0 @@
        -contents
      DIFF
    end
  end

  describe "with a HEAD commit" do
    before do
      write_file "file.txt", <<~FILE
        contents
      FILE
      jit_cmd "add", "."
      commit "first commit"
    end

    it "diffs a file with modified contents" do
      write_file "file.txt", <<~FILE
        changed
      FILE
      jit_cmd "add", "."

      assert_diff_cached <<~DIFF
        diff --git a/file.txt b/file.txt
        index 12f00e9..5ea2ed4 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -contents
        +changed
      DIFF
    end

    it "diffs a file with changed mode" do
      make_executable "file.txt"
      jit_cmd "add", "."

      assert_diff_cached <<~DIFF
        diff --git a/file.txt b/file.txt
        old mode 100644
        new mode 100755
      DIFF
    end

    it "diffs a file with changed mode and contents" do
      make_executable "file.txt"

      write_file "file.txt", <<~FILE
        changed
      FILE
      jit_cmd "add", "."

      assert_diff_cached <<~DIFF
        diff --git a/file.txt b/file.txt
        old mode 100644
        new mode 100755
        index 12f00e9..5ea2ed4
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -contents
        +changed
      DIFF
    end

    it "diffs a deleted file" do
      delete "file.txt"
      delete ".git/index"
      jit_cmd "add", "."

      assert_diff_cached <<~DIFF
        diff --git a/file.txt b/file.txt
        deleted file mode 100644
        index 12f00e9..0000000
        --- a/file.txt
        +++ /dev/null
        @@ -1,1 +0,0 @@
        -contents
      DIFF
    end

    it "diffs an added file" do
      write_file "another.txt", <<~FILE
        hello
      FILE
      jit_cmd "add", "."

      assert_diff_cached <<~DIFF
        diff --git a/another.txt b/another.txt
        new file mode 100644
        index 0000000..ce01362
        --- /dev/null
        +++ b/another.txt
        @@ -0,0 +1,1 @@
        +hello
      DIFF
    end
  end
end
