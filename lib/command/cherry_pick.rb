require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../merge/resolve"
require_relative "../revision"

module Command
  class CherryPick < Base

    include WriteCommit

    def run
      revision = Revision.new(repo, @args[0])
      commit   = repo.database.load(revision.resolve)

      pick(commit)

      exit 0
    end

    private

    def pick(commit)
      inputs = pick_merge_inputs(commit)

      resolve_merge(inputs)

      picked = Database::Commit.new([inputs.left_oid], write_tree.oid,
                                    commit.author, current_author,
                                    commit.message)

      finish_commit(picked)
    end

    def pick_merge_inputs(commit)
      short = repo.database.short_oid(commit.oid)

      left_name  = Refs::HEAD
      left_oid   = repo.refs.read_head
      right_name = "#{ short }... #{ commit.title_line.strip }"
      right_oid  = commit.oid

      ::Merge::CherryPick.new(left_name, right_name,
                              left_oid, right_oid,
                              [commit.parent])
    end

    def resolve_merge(inputs)
      repo.index.load_for_update
      ::Merge::Resolve.new(repo, inputs).execute
      repo.index.write_updates
    end

    def finish_commit(commit)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)
      print_commit(commit)
    end

  end
end
