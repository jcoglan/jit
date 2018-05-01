require "minitest/autorun"
require "command_helper"

describe Command::Log do
  include CommandHelper

  def commit_file(message)
    write_file "file.txt", message
    jit_cmd "add", "."
    commit message
  end

  describe "with a chain of commits" do

    #   o---o---o
    #   A   B   C

    before do
      messages = ["A", "B", "C"]
      messages.each { |message| commit_file message }

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
  end
end
