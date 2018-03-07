require "minitest/autorun"
require "command_helper"

describe Command::Branch do
  include CommandHelper

  describe "with a chain of commits" do
    before do
      messages = ["first", "second", "third"]

      messages.each do |message|
        write_file "file.txt", message
        jit_cmd "add", "."
        commit message
      end
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
  end
end
