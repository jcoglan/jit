require "minitest/autorun"
require "command_helper"

describe Command::Log do
  include CommandHelper

  def commit_file(message, time = nil)
    write_file "file.txt", message
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
  end
end
