require_relative "./base"
require_relative "../revision"

module Command
  class Checkout < Base

    DETACHED_HEAD_MESSAGE = <<~MSG
      You are in 'detached HEAD' state. You can look around, make experimental
      changes and commit them, and you can discard any commits you make in this
      state without impacting any branches by performing another checkout.

      If you want to create a new branch to retain commits you create, you may
      do so (now or later) by using the branch command. Example:

        jit branch <new-branch-name>
    MSG

    def run
      @target = @args[0]

      @current_ref = repo.refs.current_ref
      @current_oid = @current_ref.read_oid

      revision    = Revision.new(repo, @target)
      @target_oid = revision.resolve(Revision::COMMIT)

      repo.index.load_for_update

      tree_diff = repo.database.tree_diff(@current_oid, @target_oid)
      migration = repo.migration(tree_diff)
      migration.apply_changes

      repo.index.write_updates
      repo.refs.set_head(@target, @target_oid)
      @new_ref = repo.refs.current_ref

      print_previous_head
      print_detachment_notice
      print_new_head

      exit 0

    rescue Repository::Migration::Conflict
      handle_migration_conflict(migration)

    rescue Revision::InvalidObject => error
      handle_invalid_object(revision, error)
    end

    private

    def handle_migration_conflict(migration)
      repo.index.release_lock

      migration.errors.each do |message|
        @stderr.puts "error: #{ message }"
      end
      @stderr.puts "Aborting"
      exit 1
    end

    def handle_invalid_object(revision, error)
      revision.errors.each do |err|
        @stderr.puts "error: #{ err.message }"
        err.hint.each { |line| @stderr.puts "hint: #{ line }" }
      end
      @stderr.puts "error: #{ error.message }"
      exit 1
    end

    def print_previous_head
      if @current_ref.head? and @current_oid != @target_oid
        print_head_position("Previous HEAD position was", @current_oid)
      end
    end

    def print_detachment_notice
      return unless @new_ref.head? and not @current_ref.head?

      @stderr.puts "Note: checking out '#{ @target }'."
      @stderr.puts ""
      @stderr.puts DETACHED_HEAD_MESSAGE
      @stderr.puts ""
    end

    def print_new_head
      if @new_ref.head?
        print_head_position("HEAD is now at", @target_oid)
      elsif @new_ref == @current_ref
        @stderr.puts "Already on '#{ @target }'"
      else
        @stderr.puts "Switched to branch '#{ @target }'"
      end
    end

    def print_head_position(message, oid)
      commit = repo.database.load(oid)
      short  = repo.database.short_oid(commit.oid)

      @stderr.puts "#{ message } #{ short } #{ commit.title_line }"
    end

  end
end
