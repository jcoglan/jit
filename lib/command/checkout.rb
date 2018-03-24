require_relative "./base"
require_relative "../revision"

module Command
  class Checkout < Base

    def run
      @target = @args[0]

      @current_oid = repo.refs.read_head

      revision    = Revision.new(repo, @target)
      @target_oid = revision.resolve(Revision::COMMIT)

      tree_diff = repo.database.tree_diff(@current_oid, @target_oid)
      migration = repo.migration(tree_diff)
      migration.apply_changes

      exit 0

    rescue Revision::InvalidObject => error
      handle_invalid_object(revision, error)
    end

    private

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
