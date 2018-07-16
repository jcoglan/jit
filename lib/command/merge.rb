require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../merge/resolve"
require_relative "../revision"

module Command
  class Merge < Base

    include WriteCommit

    def run
      @inputs = ::Merge::Inputs.new(repo, Revision::HEAD, @args[0])
      resolve_merge
      commit_merge
      exit 0
    end

    private

    def resolve_merge
      repo.index.load_for_update

      merge = ::Merge::Resolve.new(repo, @inputs)
      merge.execute

      repo.index.write_updates
    end

    def commit_merge
      parents = [@inputs.left_oid, @inputs.right_oid]
      message = @stdin.read
      write_commit(parents, message)
    end

  end
end
