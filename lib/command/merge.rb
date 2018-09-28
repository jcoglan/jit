require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../merge/resolve"
require_relative "../revision"

module Command
  class Merge < Base

    include WriteCommit

    COMMIT_NOTES = <<~MSG
      Please enter a commit message to explain why this merge is necessary,
      especially if it merges an updated upstream into a topic branch.

      Lines starting with '#' will be ignored, and an empty message aborts
      the commit.
    MSG

    def define_options
      define_write_commit_options

      @options[:mode] = :run

      @parser.on("--abort")    { @options[:mode] = :abort    }
      @parser.on("--continue") { @options[:mode] = :continue }
    end

    def run
      handle_abort if @options[:mode] == :abort
      handle_continue if @options[:mode] == :continue
      handle_in_progress_merge if pending_commit.in_progress?

      @inputs = ::Merge::Inputs.new(repo, Revision::HEAD, @args[0])
      repo.refs.update_ref(Refs::ORIG_HEAD, @inputs.left_oid)

      handle_merged_ancestor if @inputs.already_merged?
      handle_fast_forward if @inputs.fast_forward?

      pending_commit.start(@inputs.right_oid)
      resolve_merge
      commit_merge

      exit 0
    end

    private

    def resolve_merge
      repo.index.load_for_update

      merge = ::Merge::Resolve.new(repo, @inputs)
      merge.on_progress { |info| puts info }
      merge.execute

      repo.index.write_updates
      fail_on_conflict if repo.index.conflict?
    end

    def fail_on_conflict
      edit_file(pending_commit.message_path) do |editor|
        editor.puts(read_message || default_commit_message)
        editor.puts("")
        editor.note("Conflicts:")
        repo.index.conflict_paths.each { |name| editor.note("\t#{ name }") }
        editor.close
      end

      puts "Automatic merge failed; fix conflicts and then commit the result."
      exit 1
    end

    def commit_merge
      parents = [@inputs.left_oid, @inputs.right_oid]
      message = compose_message

      write_commit(parents, message)

      pending_commit.clear
    end

    def compose_message
      edit_file(pending_commit.message_path) do |editor|
        editor.puts(read_message || default_commit_message)
        editor.puts("")
        editor.note(COMMIT_NOTES)

        editor.close unless @options[:edit]
      end
    end

    def default_commit_message
      "Merge commit '#{ @inputs.right_name }'"
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

    def handle_abort
      repo.pending_commit.clear

      repo.index.load_for_update
      repo.hard_reset(repo.refs.read_head)
      repo.index.write_updates

      exit 0
    rescue Repository::PendingCommit::Error => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

    def handle_continue
      repo.index.load
      resume_merge(:merge)
    rescue Repository::PendingCommit::Error => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

    def handle_in_progress_merge
      message = "Merging is not possible because you have unmerged files"
      @stderr.puts "error: #{ message }."
      @stderr.puts CONFLICT_MESSAGE
      exit 128
    end

  end
end
