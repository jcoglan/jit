require_relative "./base"
require_relative "./shared/sequencing"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../rev_list"

module Command
  class Revert < Base

    include Sequencing
    include WriteCommit

    private

    def merge_type
      :revert
    end

    def store_commit_sequence
      commits = RevList.new(repo, @args, :walk => false)
      commits.each { |commit| sequencer.revert(commit) }
    end

    def revert(commit)
      inputs  = revert_merge_inputs(commit)
      message = revert_commit_message(commit)

      resolve_merge(inputs)
      fail_on_conflict(inputs, message) if repo.index.conflict?

      author  = current_author
      message = edit_revert_message(message)
      picked  = Database::Commit.new([inputs.left_oid], write_tree.oid,
                                     author, author, message)

      finish_commit(picked)
    end

    def revert_merge_inputs(commit)
      short = repo.database.short_oid(commit.oid)

      left_name  = Refs::HEAD
      left_oid   = repo.refs.read_head
      right_name = "parent of #{ short }... #{ commit.title_line.strip }"
      right_oid  = commit.parent

      ::Merge::CherryPick.new(left_name, right_name,
                              left_oid, right_oid,
                              [commit.oid])
    end

    def revert_commit_message(commit)
      <<~MESSAGE
        Revert "#{ commit.title_line.strip }"

        This reverts commit #{ commit.oid }.
      MESSAGE
    end

    def edit_revert_message(message)
      edit_file(commit_message_path) do |editor|
        editor.puts(message)
        editor.puts("")
        editor.note(Commit::COMMIT_NOTES)
      end
    end

  end
end
