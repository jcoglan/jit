require "pathname"

require_relative "./base"
require_relative "../repository/inspector"

module Command
  class Rm < Base

    def run
      repo.index.load_for_update

      @head_oid    = repo.refs.read_head
      @inspector   = Repository::Inspector.new(repo)
      @uncommitted = []
      @unstaged    = []

      @args.each { |path| plan_removal(Pathname.new(path)) }
      exit_on_errors

      @args.each { |path| remove_file(path) }
      repo.index.write_updates

      exit 0
    end

    private

    def plan_removal(path)
      item  = repo.database.load_tree_entry(@head_oid, path)
      entry = repo.index.entry_for_path(path)
      stat  = repo.workspace.stat_file(path)

      if @inspector.compare_tree_to_index(item, entry)
        @uncommitted.push(path)
      elsif stat and @inspector.compare_index_to_workspace(entry, stat)
        @unstaged.push(path)
      end
    end

    def remove_file(path)
      repo.index.remove(path)
      repo.workspace.remove(path)
      puts "rm '#{ path }'"
    end

    def exit_on_errors
      return if @uncommitted.empty? and @unstaged.empty?

      print_errors(@uncommitted, "changes staged in the index")
      print_errors(@unstaged, "local modifications")

      repo.index.release_lock
      exit 1
    end

    def print_errors(paths, message)
      return if paths.empty?

      files_have = (paths.size == 1) ? "file has" : "files have"

      @stderr.puts "error: the following #{ files_have } #{ message }:"
      paths.each { |path| @stderr.puts "    #{ path }" }
    end

  end
end
