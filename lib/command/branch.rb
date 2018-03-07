require_relative "./base"
require_relative "../revision"

module Command
  class Branch < Base

    def run
      create_branch

      exit 0
    end

    private

    def create_branch
      branch_name = @args[0]
      start_point = @args[1]

      if start_point
        revision  = Revision.new(repo, start_point)
        start_oid = revision.resolve
      else
        start_oid = repo.refs.read_head
      end

      repo.refs.create_branch(branch_name, start_oid)

    rescue Refs::InvalidBranch, Revision::InvalidObject => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

  end
end
