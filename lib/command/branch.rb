require_relative "./base"

module Command
  class Branch < Base

    def run
      create_branch

      exit 0
    end

    private

    def create_branch
      branch_name = @args[0]
      repo.refs.create_branch(branch_name)
    rescue Refs::InvalidBranch => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

  end
end
