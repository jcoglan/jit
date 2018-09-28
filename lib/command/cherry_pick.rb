require_relative "./base"
require_relative "./shared/write_commit"
require_relative "../merge/inputs"
require_relative "../merge/resolve"
require_relative "../revision"

module Command
  class CherryPick < Base

    include WriteCommit

    CONFLICT_NOTES = <<~MSG
      after resolving the conflicts, mark the corrected paths
      with 'jit add <paths>' or 'jit rm <paths>'
      and commit the result with 'jit commit'
    MSG

    def define_options
      @options[:mode] = :run
      @parser.on("--continue") { @options[:mode] = :continue }
    end

    def run
      handle_continue if @options[:mode] == :continue

      revision = Revision.new(repo, @args[0])
      commit   = repo.database.load(revision.resolve)

      pick(commit)

      exit 0
    end

    private

    def merge_type
      :cherry_pick
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

    def resolve_merge(inputs)
      repo.index.load_for_update
      ::Merge::Resolve.new(repo, inputs).execute
      repo.index.write_updates
    end

    def fail_on_conflict(inputs, message)
      pending_commit.start(inputs.right_oid, merge_type)

      edit_file(pending_commit.message_path) do |editor|
        editor.puts(message)
        editor.puts("")
        editor.note("Conflicts:")
        repo.index.conflict_paths.each { |name| editor.note("\t#{ name }") }
        editor.close
      end

      @stderr.puts "error: could not apply #{ inputs.right_name }"
      CONFLICT_NOTES.each_line { |line| @stderr.puts "hint: #{ line }" }
      exit 1
    end

    def finish_commit(commit)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)
      print_commit(commit)
    end

    def handle_continue
      repo.index.load
      write_cherry_pick_commit
      exit 0
    rescue Repository::PendingCommit::Error => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

  end
end
