require "pathname"
require_relative "./base"
require_relative "./shared/write_commit"

module Command
  class Commit < Base

    include WriteCommit

    COMMIT_NOTES = <<~MSG
      Please enter the commit message for your changes. Lines starting
      with '#' will be ignored, and an empty message aborts the commit.
    MSG

    def define_options
      define_write_commit_options
    end

    def run
      repo.index.load
      resume_merge if pending_commit.in_progress?

      parent  = repo.refs.read_head
      message = compose_message(read_message)
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

  end
end
