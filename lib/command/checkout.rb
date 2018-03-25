require_relative "./base"
require_relative "../revision"

module Command
  class Checkout < Base

    def run
      @target = @args[0]

      @current_oid = repo.refs.read_head

      revision    = Revision.new(repo, @target)
      @target_oid = revision.resolve(Revision::COMMIT)

      repo.index.load_for_update

      tree_diff = repo.database.tree_diff(@current_oid, @target_oid)
      migration = repo.migration(tree_diff)
      migration.apply_changes

      repo.index.write_updates
      repo.refs.update_head(@target_oid)

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

  end
end
