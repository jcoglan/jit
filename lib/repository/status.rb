require "set"

require_relative "./inspector"
require_relative "../sorted_hash"

class Repository
  class Status

    attr_reader :changed,
                :stats,
                :head_tree,
                :index_changes,
                :conflicts,
                :workspace_changes,
                :untracked_files

    def initialize(repository, commit_oid = nil)
      @repo  = repository
      @stats = {}

      @inspector = Inspector.new(@repo)

      @changed           = SortedSet.new
      @index_changes     = SortedHash.new
      @conflicts         = SortedHash.new
      @workspace_changes = SortedHash.new
      @untracked_files   = SortedSet.new

      commit_oid ||= @repo.refs.read_head
      @head_tree   = @repo.database.load_tree_list(commit_oid)

      scan_workspace
      check_index_entries
      collect_deleted_head_files
    end

    private

    def record_change(path, set, type)
      @changed.add(path)
      set[path] = type
    end

    def scan_workspace(prefix = nil)
      @repo.workspace.list_dir(prefix).each do |path, stat|
        if @repo.index.tracked?(path)
          @stats[path] = stat if stat.file?
          scan_workspace(path) if stat.directory?
        elsif @inspector.trackable_file?(path, stat)
          path += File::SEPARATOR if stat.directory?
          @untracked_files.add(path)
        end
      end
    end

    def check_index_entries
      @repo.index.each_entry do |entry|
        if entry.stage == 0
          check_index_against_workspace(entry)
          check_index_against_head_tree(entry)
        else
          @changed.add(entry.path)
          @conflicts[entry.path] ||= []
          @conflicts[entry.path].push(entry.stage)
        end
      end
    end

    def check_index_against_workspace(entry)
      stat   = @stats[entry.path]
      status = @inspector.compare_index_to_workspace(entry, stat)

      if status
        record_change(entry.path, @workspace_changes, status)
      else
        @repo.index.update_entry_stat(entry, stat)
      end
    end

    def check_index_against_head_tree(entry)
      item   = @head_tree[entry.path]
      status = @inspector.compare_tree_to_index(item, entry)

      if status
        record_change(entry.path, @index_changes, status)
      end
    end

    def collect_deleted_head_files
      @head_tree.each_key do |path|
        unless @repo.index.tracked_file?(path)
          record_change(path, @index_changes, :deleted)
        end
      end
    end

  end
end
