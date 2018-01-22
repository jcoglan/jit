require "set"
require_relative "./base"

module Command
  class Status < Base

    def run
      @stats     = {}
      @changed   = SortedSet.new
      @changes   = Hash.new { |hash, key| hash[key] = Set.new }
      @untracked = SortedSet.new

      repo.index.load_for_update

      scan_workspace
      detect_workspace_changes

      repo.index.write_updates

      print_results
      exit 0
    end

    private

    def print_results
      @changed.each do |path|
        status = status_for(path)
        puts "#{ status } #{ path }"
      end

      @untracked.each do |path|
        puts "?? #{ path }"
      end
    end

    def status_for(path)
      changes = @changes[path]

      status = "  "
      status = " D" if changes.include?(:workspace_deleted)
      status = " M" if changes.include?(:workspace_modified)

      status
    end

    def record_change(path, type)
      @changed.add(path)
      @changes[path].add(type)
    end

    def scan_workspace(prefix = nil)
      repo.workspace.list_dir(prefix).each do |path, stat|
        if repo.index.tracked?(path)
          @stats[path] = stat if stat.file?
          scan_workspace(path) if stat.directory?
        elsif trackable_file?(path, stat)
          path += File::SEPARATOR if stat.directory?
          @untracked.add(path)
        end
      end
    end

    def trackable_file?(path, stat)
      return false unless stat

      return !repo.index.tracked?(path) if stat.file?
      return false unless stat.directory?

      items = repo.workspace.list_dir(path)
      files = items.select { |_, item_stat| item_stat.file? }
      dirs  = items.select { |_, item_stat| item_stat.directory? }

      [files, dirs].any? do |list|
        list.any? { |item_path, item_stat| trackable_file?(item_path, item_stat) }
      end
    end

    def detect_workspace_changes
      repo.index.each_entry { |entry| check_index_entry(entry) }
    end

    def check_index_entry(entry)
      stat = @stats[entry.path]

      unless stat
        return record_change(entry.path, :workspace_deleted)
      end

      unless entry.stat_match?(stat)
        return record_change(entry.path, :workspace_modified)
      end

      return if entry.times_match?(stat)

      data = repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid  = repo.database.hash_object(blob)

      if entry.oid == oid
        repo.index.update_entry_stat(entry, stat)
      else
        record_change(entry.path, :workspace_modified)
      end
    end

  end
end
