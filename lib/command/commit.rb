require "pathname"
require_relative "./base"
require_relative "./shared/write_commit"

module Command
  class Commit < Base

    include WriteCommit

    def define_options
      define_write_commit_options
    end

    def run
      repo.index.load
      resume_merge if pending_commit.in_progress?

      parent  = repo.refs.read_head
      message = read_message
      commit  = write_commit([*parent], message)

      print_commit(commit)

      exit 0
    end

  end
end
