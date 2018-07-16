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
      handle_merged_ancestor if @inputs.already_merged?
      handle_fast_forward if @inputs.fast_forward?

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

    def handle_merged_ancestor
      puts "Already up to date."
      exit 0
    end

    def handle_fast_forward
      a = repo.database.short_oid(@inputs.left_oid)
      b = repo.database.short_oid(@inputs.right_oid)

      puts "Updating #{ a }..#{ b }"
      puts "Fast-forward"

      repo.index.load_for_update

      tree_diff = repo.database.tree_diff(@inputs.left_oid, @inputs.right_oid)
      repo.migration(tree_diff).apply_changes

      repo.index.write_updates
      repo.refs.update_head(@inputs.right_oid)

      exit 0
    end

  end
end
