require_relative "./base"
require_relative "../repository/inspector"

module Command
  class Rm < Base

    def run
      repo.index.load_for_update

      @inspector = Repository::Inspector.new(repo)
      @unstaged  = []

      @args.each { |path| plan_removal(path) }
      exit_on_errors

      @args.each { |path| remove_file(path) }
      repo.index.write_updates

      exit 0
    end

    private

    def plan_removal(path)
      entry = repo.index.entry_for_path(path)
      stat  = repo.workspace.stat_file(path)

      if stat and @inspector.compare_index_to_workspace(entry, stat)
        @unstaged.push(path)
      end
    end

    def remove_file(path)
      repo.index.remove(path)
      repo.workspace.remove(path)
      puts "rm '#{ path }'"
    end

    def exit_on_errors
      return if @unstaged.empty?

      files_have = (@unstaged.size == 1) ? "file has" : "files have"

      @stderr.puts "error: the following #{ files_have } local modifications:"
      @unstaged.each { |path| @stderr.puts "    #{ path }" }

      repo.index.release_lock
      exit 1
    end

  end
end
