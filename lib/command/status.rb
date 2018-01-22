require "set"
require_relative "./base"

module Command
  class Status < Base

    def run
      repo.index.load

      @stats     = {}
      @changed   = SortedSet.new
      @untracked = SortedSet.new

      scan_workspace
      detect_workspace_changes

      @changed.each   { |path| puts " M #{ path }" }
      @untracked.each { |path| puts "?? #{ path }" }

      exit 0
    end

    private

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
      return @changed.add(entry.path) unless entry.stat_match?(stat)

      data = repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid  = repo.database.hash_object(blob)

      @changed.add(entry.path) unless entry.oid == oid
    end

  end
end
