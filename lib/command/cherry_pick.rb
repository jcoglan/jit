require_relative "./base"
require_relative "./shared/sequencing"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../rev_list"

module Command
  class CherryPick < Base

    include Sequencing
    include WriteCommit

    private

    def merge_type
      :cherry_pick
    end

    def store_commit_sequence
      commits = RevList.new(repo, @args.reverse, :walk => false)
      commits.reverse_each { |commit| sequencer.pick(commit) }
    end

    def pick(commit)
      inputs = pick_merge_inputs(commit)
      resolve_merge(inputs)
      fail_on_conflict(inputs, commit.message) if repo.index.conflict?

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

  end
end
