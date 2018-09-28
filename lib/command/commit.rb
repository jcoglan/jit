require "pathname"
require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../revision"

module Command
  class Commit < Base

    include WriteCommit

    COMMIT_NOTES = <<~MSG
      Please enter the commit message for your changes. Lines starting
      with '#' will be ignored, and an empty message aborts the commit.
    MSG

    def define_options
      define_write_commit_options

      @parser.on("--amend") { @options[:amend] = true }

      @parser.on "-C <commit>", "--reuse-message=<commit>" do |commit|
        @options[:reuse] = commit
        @options[:edit]  = false
      end

      @parser.on "-c <commit>", "--reedit-message=<commit>" do |commit|
        @options[:reuse] = commit
        @options[:edit]  = true
      end
    end

    def run
      repo.index.load

      handle_amend if @options[:amend]

      merge_type = pending_commit.merge_type
      resume_merge(merge_type) if merge_type

      parent  = repo.refs.read_head
      message = compose_message(read_message || reused_message)
      commit  = write_commit([*parent], message)

      print_commit(commit)

      exit 0
    end

    private

    def compose_message(message)
      edit_file(commit_message_path) do |editor|
        editor.puts(message || "")
        editor.puts("")
        editor.note(COMMIT_NOTES)

        editor.close unless @options[:edit]
      end
    end

    def reused_message
      return nil unless @options.has_key?(:reuse)

      revision = Revision.new(repo, @options[:reuse])
      commit   = repo.database.load(revision.resolve)

      commit.message
    end

    def handle_amend
      old  = repo.database.load(repo.refs.read_head)
      tree = write_tree

      message   = compose_message(old.message)
      committer = current_author

      new = Database::Commit.new(old.parents, tree.oid, old.author, committer, message)
      repo.database.store(new)
      repo.refs.update_head(new.oid)

      print_commit(new)
      exit 0
    end

  end
end
