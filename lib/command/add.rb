require "pathname"

require_relative "./base"
require_relative "../repository"

module Command
  class Add < Base

    def run
      root_path = Pathname.new(@dir)
      repo = Repository.new(root_path.join(".git"))

      begin
        repo.index.load_for_update
      rescue Lockfile::LockDenied => error
        @stderr.puts <<~ERROR
          fatal: #{ error.message }

          Another jit process seems to be running in this repository.
          Please make sure all processes are terminated then try again.
          If it still fails, a jit process may have crashed in this
          repository earlier: remove the file manually to continue.
        ERROR
        exit 128
      end

      begin
        paths = @args.flat_map do |path|
          path = expanded_pathname(path)
          repo.workspace.list_files(path)
        end
      rescue Workspace::MissingFile => error
        @stderr.puts "fatal: #{ error.message }"
        repo.index.release_lock
        exit 128
      end

      begin
        paths.each do |path|
          data = repo.workspace.read_file(path)
          stat = repo.workspace.stat_file(path)

          blob = Database::Blob.new(data)
          repo.database.store(blob)
          repo.index.add(path, blob.oid, stat)
        end
      rescue Workspace::NoPermission => error
        @stderr.puts "error: #{ error.message }"
        @stderr.puts "fatal: adding files failed"
        repo.index.release_lock
        exit 128
      end

      repo.index.write_updates
      exit 0
    end

  end
end
