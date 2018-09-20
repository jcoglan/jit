require "minitest/autorun"
require "command_helper"

describe Command::Log do
  include CommandHelper

  def commit_file(message, time = nil)
    write_file "file.txt", message
    jit_cmd "add", "."
    commit message, time
  end

  def commit_tree(message, files, time = nil)
    files.each do |path, contents|
      write_file path, contents
    end
    jit_cmd "add", "."
    commit message, time
  end

  describe "with a chain of commits" do

    #   o---o---o
    #   A   B   C

    before do
      messages = ["A", "B", "C"]
      messages.each { |message| commit_file message }

      jit_cmd "branch", "topic", "@^^"

      @commits = ["@", "@^", "@^^"].map { |rev| load_commit(rev) }
    end

    it "prints a log in medium format" do
      jit_cmd "log"

      assert_stdout <<~LOGS
        commit #{ @commits[0].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[0].author.readable_time }

            C

        commit #{ @commits[1].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[1].author.readable_time }

            B

        commit #{ @commits[2].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[2].author.readable_time }

            A
      LOGS
    end

    it "prints a log in medium format with abbreviated commit IDs" do
      jit_cmd "log", "--abbrev-commit"

      assert_stdout <<~LOGS
        commit #{ repo.database.short_oid @commits[0].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[0].author.readable_time }

            C

        commit #{ repo.database.short_oid @commits[1].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[1].author.readable_time }

            B

        commit #{ repo.database.short_oid @commits[2].oid }
        Author: A. U. Thor <author@example.com>
        Date:   #{ @commits[2].author.readable_time }

            A
      LOGS
    end

    it "prints a log in oneline format" do
      jit_cmd "log", "--oneline"

      assert_stdout <<~LOGS
        #{ repo.database.short_oid @commits[0].oid } C
        #{ repo.database.short_oid @commits[1].oid } B
        #{ repo.database.short_oid @commits[2].oid } A
      LOGS
    end

    it "prints a log in oneline format without abbreviated commit IDs" do
      jit_cmd "log", "--pretty=oneline"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } C
        #{ @commits[1].oid } B
        #{ @commits[2].oid } A
      LOGS
    end

    it "prints a log starting from a specified commit" do
      jit_cmd "log", "--pretty=oneline", "@^"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } B
        #{ @commits[2].oid } A
      LOGS
    end

    it "prints a log with short decorations" do
      jit_cmd "log", "--pretty=oneline", "--decorate=short"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } (HEAD -> master) C
        #{ @commits[1].oid } B
        #{ @commits[2].oid } (topic) A
      LOGS
    end

    it "prints a log with detached HEAD" do
      jit_cmd "checkout", "@"
      jit_cmd "log", "--pretty=oneline", "--decorate=short"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } (HEAD, master) C
        #{ @commits[1].oid } B
        #{ @commits[2].oid } (topic) A
      LOGS
    end

    it "prints a log with full decorations" do
      jit_cmd "log", "--pretty=oneline", "--decorate=full"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } (HEAD -> refs/heads/master) C
        #{ @commits[1].oid } B
        #{ @commits[2].oid } (refs/heads/topic) A
      LOGS
    end

    it "prints a log with patches" do
      jit_cmd "log", "--pretty=oneline", "--patch"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } C
        diff --git a/file.txt b/file.txt
        index 7371f47..96d80cd 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -B
        +C
        #{ @commits[1].oid } B
        diff --git a/file.txt b/file.txt
        index 8c7e5a6..7371f47 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -A
        +B
        #{ @commits[2].oid } A
        diff --git a/file.txt b/file.txt
        new file mode 100644
        index 0000000..8c7e5a6
        --- /dev/null
        +++ b/file.txt
        @@ -0,0 +1,1 @@
        +A
      LOGS
    end
  end

  describe "with commits changing different files" do
    before do
      commit_tree "first",
        "a/1.txt"   => "1",
        "b/c/2.txt" => "2"

      commit_tree "second",
        "a/1.txt" => "10",
        "b/3.txt" => "3"

      commit_tree "third",
        "b/c/2.txt" => "4"

      @commits = ["@^^", "@^", "@"].map { |rev| load_commit(rev) }
    end

    it "logs commits that change a file" do
      jit_cmd "log", "--pretty=oneline", "a/1.txt"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } second
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits that change a directory" do
      jit_cmd "log", "--pretty=oneline", "b"

      assert_stdout <<~LOGS
        #{ @commits[2].oid } third
        #{ @commits[1].oid } second
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits that change a directory and one of its files" do
      jit_cmd "log", "--pretty=oneline", "b", "b/3.txt"

      assert_stdout <<~LOGS
        #{ @commits[2].oid } third
        #{ @commits[1].oid } second
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits that change a nested directory" do
      jit_cmd "log", "--pretty=oneline", "b/c"

      assert_stdout <<~LOGS
        #{ @commits[2].oid } third
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits with patches for selected files" do
      jit_cmd "log", "--pretty=oneline", "--patch", "a/1.txt"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } second
        diff --git a/a/1.txt b/a/1.txt
        index 56a6051..9a03714 100644
        --- a/a/1.txt
        +++ b/a/1.txt
        @@ -1,1 +1,1 @@
        -1
        +10
        #{ @commits[0].oid } first
        diff --git a/a/1.txt b/a/1.txt
        new file mode 100644
        index 0000000..56a6051
        --- /dev/null
        +++ b/a/1.txt
        @@ -0,0 +1,1 @@
        +1
      LOGS
    end
  end

  describe "with a tree of commits" do

    #  m1  m2  m3
    #   o---o---o [master]
    #        \
    #         o---o---o---o [topic]
    #        t1  t2  t3  t4

    before do
      (1..3).each { |n| commit_file "master-#{n}" }

      jit_cmd "branch", "topic", "master^"
      jit_cmd "checkout", "topic"

      @branch_time = Time.now + 10
      (1..4).each { |n| commit_file "topic-#{n}", @branch_time }

      @master = (0..2).map { |n| resolve_revision("master~#{n}") }
      @topic  = (0..3).map { |n| resolve_revision("topic~#{n}") }
    end

    it "logs the combined history of multiple branches" do
      jit_cmd "log", "--pretty=oneline", "--decorate=short", "master", "topic"

      assert_stdout <<~LOGS
        #{ @topic[0]  } (HEAD -> topic) topic-4
        #{ @topic[1]  } topic-3
        #{ @topic[2]  } topic-2
        #{ @topic[3]  } topic-1
        #{ @master[0] } (master) master-3
        #{ @master[1] } master-2
        #{ @master[2] } master-1
      LOGS
    end

    it "logs the difference from one one branch to another" do
      jit_cmd "log", "--pretty=oneline", "master..topic"

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
        #{ @topic[2] } topic-2
        #{ @topic[3] } topic-1
      LOGS

      jit_cmd "log", "--pretty=oneline", "master", "^topic"

      assert_stdout <<~LOGS
        #{ @master[0] } master-3
      LOGS
    end

    it "excludes a long branch when commit times are equal" do
      jit_cmd "branch", "side", "topic^^"
      jit_cmd "checkout", "side"

      (1..10).each { |n| commit_file "side-#{n}", @branch_time }

      jit_cmd "log", "--pretty=oneline", "side..topic", "^master"

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
      LOGS
    end

    it "logs the last few commits on a branch" do
      jit_cmd "log", "--pretty=oneline", "@~3.."

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
        #{ @topic[2] } topic-2
      LOGS
    end
  end

  describe "with a graph of commits" do

    #   A   B   C   D   J   K
    #   o---o---o---o---o---o [master]
    #        \         /
    #         o---o---o---o [topic]
    #         E   F   G   H

    before do
      time = Time.now

      commit_tree "A", { "f.txt" => "0", "g.txt" => "0" }, time
      commit_tree "B", { "f.txt" => "B", "h.txt" => <<~EOF }, time
        one
        two
        three
      EOF

      ("C".."D").each { |n| commit_tree n, { "f.txt" => n, "h.txt" => <<~EOF }, time + 1 }
        #{ n }
        two
        three
      EOF

      jit_cmd "branch", "topic", "master~2"
      jit_cmd "checkout", "topic"

      ("E".."H").each { |n| commit_tree n, { "g.txt" => n , "h.txt" => <<~EOF }, time + 2 }
        one
        two
        #{ n }
      EOF

      jit_cmd "checkout", "master"
      jit_cmd "merge", "topic^", "-m", "J"

      commit_tree "K", { "f.txt" => "K" }, time + 3

      @master = (0..5).map { |n| resolve_revision("master~#{n}") }
      @topic  = (0..3).map { |n| resolve_revision("topic~#{n}") }
    end

    it "logs concurrent branches leading to a merge" do
      jit_cmd "log", "--pretty=oneline"

      assert_stdout <<~LOGS
        #{ @master[0] } K
        #{ @master[1] } J
        #{ @topic[1]  } G
        #{ @topic[2]  } F
        #{ @topic[3]  } E
        #{ @master[2] } D
        #{ @master[3] } C
        #{ @master[4] } B
        #{ @master[5] } A
      LOGS
    end

    it "logs the first parent of a merge" do
      jit_cmd "log", "--pretty=oneline", "master^^"

      assert_stdout <<~LOGS
        #{ @master[2] } D
        #{ @master[3] } C
        #{ @master[4] } B
        #{ @master[5] } A
      LOGS
    end

    it "logs the second parent of a merge" do
      jit_cmd "log", "--pretty=oneline", "master^^2"

      assert_stdout <<~LOGS
        #{ @topic[1]  } G
        #{ @topic[2]  } F
        #{ @topic[3]  } E
        #{ @master[4] } B
        #{ @master[5] } A
      LOGS
    end

    it "logs unmerged commits on a branch" do
      jit_cmd "log", "--pretty=oneline", "master..topic"

      assert_stdout <<~LOGS
        #{ @topic[0] } H
      LOGS
    end

    it "does not show patches for merge commits" do
      jit_cmd "log", "--pretty=oneline", "--patch", "topic..master", "^master^^^"

      assert_stdout <<~LOGS
        #{ @master[0] } K
        diff --git a/f.txt b/f.txt
        index 02358d2..449e49e 100644
        --- a/f.txt
        +++ b/f.txt
        @@ -1,1 +1,1 @@
        -D
        +K
        #{ @master[1] } J
        #{ @master[2] } D
        diff --git a/f.txt b/f.txt
        index 96d80cd..02358d2 100644
        --- a/f.txt
        +++ b/f.txt
        @@ -1,1 +1,1 @@
        -C
        +D
        diff --git a/h.txt b/h.txt
        index 4e5ce14..4139691 100644
        --- a/h.txt
        +++ b/h.txt
        @@ -1,3 +1,3 @@
        -C
        +D
         two
         three
      LOGS
    end

    it "shows combined patches for merges" do
      jit_cmd "log", "--pretty=oneline", "--cc", "topic..master", "^master^^^"

      assert_stdout <<~LOGS
        #{ @master[0] } K
        diff --git a/f.txt b/f.txt
        index 02358d2..449e49e 100644
        --- a/f.txt
        +++ b/f.txt
        @@ -1,1 +1,1 @@
        -D
        +K
        #{ @master[1] } J
        diff --cc h.txt
        index 4139691,f3e97ee..4e78f4f
        --- a/h.txt
        +++ b/h.txt
        @@@ -1,3 -1,3 +1,3 @@@
         -one
         +D
          two
        - three
        + G
        #{ @master[2] } D
        diff --git a/f.txt b/f.txt
        index 96d80cd..02358d2 100644
        --- a/f.txt
        +++ b/f.txt
        @@ -1,1 +1,1 @@
        -C
        +D
        diff --git a/h.txt b/h.txt
        index 4e5ce14..4139691 100644
        --- a/h.txt
        +++ b/h.txt
        @@ -1,3 +1,3 @@
        -C
        +D
         two
         three
      LOGS
    end

    it "does not list merges with treesame parents for prune paths" do
      jit_cmd "log", "--pretty=oneline", "g.txt"

      assert_stdout <<~LOGS
        #{ @topic[1]  } G
        #{ @topic[2]  } F
        #{ @topic[3]  } E
        #{ @master[5] } A
      LOGS
    end

    describe "with changes that are undone on a branch leading to a merge" do
      before do
        time = Time.now

        jit_cmd "branch", "aba", "master~4"
        jit_cmd "checkout", "aba"

        ["C", "0"].each { |n| commit_tree n, { "g.txt" => n }, time + 1 }

        jit_cmd "merge", "topic^", "-m", "J"
        commit_tree "K", { "f.txt" => "K" }, time + 3
      end

      it "does not list commits on the filtered branch" do
        jit_cmd "log", "--pretty=oneline", "g.txt"

        assert_stdout <<~LOGS
          #{ @topic[1]  } G
          #{ @topic[2]  } F
          #{ @topic[3]  } E
          #{ @master[5] } A
        LOGS
      end
    end
  end
end
