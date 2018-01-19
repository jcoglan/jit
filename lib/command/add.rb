require "pathname"
require_relative "./base"

module Command
  class Add < Base

    LOCKED_INDEX_MESSAGE = <<~MSG
      Another jit process seems to be running in this repository.
      Please make sure all processes are terminated then try again.
      If it still fails, a jit process may have crashed in this
      repository earlier: remove the file manually to continue.
    MSG

    def run
      repo.index.load_for_update
      expanded_paths.each { |path| add_to_index(path) }
      repo.index.write_updates
      exit 0
    rescue Lockfile::LockDenied => error
      handle_locked_index(error)
    rescue Workspace::MissingFile => error
      handle_missing_file(error)
    rescue Workspace::NoPermission => error
      handle_unreadable_file(error)
    end

    private

    def expanded_paths
      @args.flat_map do |path|
        repo.workspace.list_files(expanded_pathname(path))
      end
    end

    def add_to_index(path)
      data = repo.workspace.read_file(path)
      stat = repo.workspace.stat_file(path)

      blob = Database::Blob.new(data)
      repo.database.store(blob)
      repo.index.add(path, blob.oid, stat)
    end

    def handle_locked_index(error)
      @stderr.puts "fatal: #{ error.message }"
      @stderr.puts
      @stderr.puts LOCKED_INDEX_MESSAGE
      exit 128
    end

    def handle_missing_file(error)
      @stderr.puts "fatal: #{ error.message }"
      repo.index.release_lock
      exit 128
    end

    def handle_unreadable_file(error)
      @stderr.puts "error: #{ error.message }"
      @stderr.puts "fatal: adding files failed"
      repo.index.release_lock
      exit 128
    end

  end
end
