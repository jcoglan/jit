class Repository
  class Inspector

    def initialize(repository)
      @repo = repository
    end

    def trackable_file?(path, stat)
      return false unless stat

      return !@repo.index.tracked_file?(path) if stat.file?
      return false unless stat.directory?

      items = @repo.workspace.list_dir(path)
      files = items.select { |_, item_stat| item_stat.file? }
      dirs  = items.select { |_, item_stat| item_stat.directory? }

      [files, dirs].any? do |list|
        list.any? { |item_path, item_stat| trackable_file?(item_path, item_stat) }
      end
    end

    def compare_index_to_workspace(entry, stat)
      return :untracked unless entry
      return :deleted unless stat
      return :modified unless entry.stat_match?(stat)
      return nil if entry.times_match?(stat)

      data = @repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid  = @repo.database.hash_object(blob)

      unless entry.oid == oid
        :modified
      end
    end

    def compare_tree_to_index(item, entry)
      return nil unless item or entry
      return :added unless item
      return :deleted unless entry

      unless entry.mode == item.mode and entry.oid == item.oid
        :modified
      end
    end

  end
end
