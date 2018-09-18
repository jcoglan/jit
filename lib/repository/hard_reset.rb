require "pathname"

class Repository
  class HardReset

    def initialize(repo, oid)
      @repo = repo
      @oid  = oid
    end

    def execute
      @status = @repo.status(@oid)
      changed = @status.changed.map { |path| Pathname.new(path) }

      changed.each { |path| reset_path(path) }
    end

    private

    def reset_path(path)
      @repo.index.remove(path)
      @repo.workspace.remove(path)

      entry = @status.head_tree[path.to_s]
      return unless entry

      blob = @repo.database.load(entry.oid)
      @repo.workspace.write_file(path, blob.data, entry.mode, true)

      stat = @repo.workspace.stat_file(path)
      @repo.index.add(path, entry.oid, stat)
    end

  end
end
