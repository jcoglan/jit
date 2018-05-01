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
  end
end
