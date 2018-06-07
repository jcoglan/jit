require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../merge/bases"
require_relative "../revision"

module Command
  class Merge < Base

    include WriteCommit

    def run
      head_oid  = repo.refs.read_head
      revision  = Revision.new(repo, @args[0])
      merge_oid = revision.resolve(Revision::COMMIT)

      common   = ::Merge::Bases.new(repo.database, head_oid, merge_oid)
      base_oid = common.find.first

      repo.index.load_for_update

      tree_diff = repo.database.tree_diff(base_oid, merge_oid)
      migration = repo.migration(tree_diff)
      migration.apply_changes

      repo.index.write_updates

      message = @stdin.read
      write_commit([head_oid, merge_oid], message)

      exit 0
    end

  end
end
