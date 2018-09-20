require "pathname"
require_relative "./base"
require_relative "./shared/write_commit"

module Command
  class Commit < Base

    include WriteCommit

    def run
      repo.index.load
      resume_merge if pending_commit.in_progress?

      parent  = repo.refs.read_head
      message = @stdin.read
      commit  = write_commit([*parent], message)

      print_commit(commit)

      exit 0
    end

  end
end
