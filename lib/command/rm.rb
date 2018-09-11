require "pathname"

require_relative "./base"
require_relative "../repository/inspector"

module Command
  class Rm < Base

    BOTH_CHANGED      = "staged content different from both the file and the HEAD"
    INDEX_CHANGED     = "changes staged in the index"
    WORKSPACE_CHANGED = "local modifications"

    def define_options
      @parser.on("--cached")      { @options[:cached]    = true }
      @parser.on("-f", "--force") { @options[:force]     = true }
      @parser.on("-r")            { @options[:recursive] = true }
    end

    def run
      repo.index.load_for_update

      @head_oid     = repo.refs.read_head
      @inspector    = Repository::Inspector.new(repo)
      @uncommitted  = []
      @unstaged     = []
      @both_changed = []

      @args = @args.flat_map { |path| expand_path(path) }
                   .map { |path| Pathname.new(path) }

      @args.each { |path| plan_removal(path) }
      exit_on_errors

      @args.each { |path| remove_file(path) }
      repo.index.write_updates

      exit 0

    rescue => error
      repo.index.release_lock
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

    private

    def expand_path(path)
      if repo.index.tracked_directory?(path)
        return repo.index.child_paths(path) if @options[:recursive]
        raise "not removing '#{ path }' recursively without -r"
      end

      return [path] if repo.index.tracked_file?(path)
      raise "pathspec '#{ path }' did not match any files"
    end

    def plan_removal(path)
      return if @options[:force]

      stat = repo.workspace.stat_file(path)
      raise "jit rm: '#{ path }': Operation not permitted" if stat&.directory?

      item  = repo.database.load_tree_entry(@head_oid, path)
      entry = repo.index.entry_for_path(path)

      staged_change   = @inspector.compare_tree_to_index(item, entry)
      unstaged_change = @inspector.compare_index_to_workspace(entry, stat) if stat

      if staged_change and unstaged_change
        @both_changed.push(path)
      elsif staged_change
        @uncommitted.push(path) unless @options[:cached]
      elsif unstaged_change
        @unstaged.push(path) unless @options[:cached]
      end
    end

    def remove_file(path)
      repo.index.remove(path)
      repo.workspace.remove(path) unless @options[:cached]
      puts "rm '#{ path }'"
    end

    def exit_on_errors
      return if [@both_changed, @uncommitted, @unstaged].all?(&:empty?)

      print_errors(@both_changed, BOTH_CHANGED)
      print_errors(@uncommitted, INDEX_CHANGED)
      print_errors(@unstaged, WORKSPACE_CHANGED)

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
