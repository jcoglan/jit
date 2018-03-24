require "set"

class Repository
  class Migration

    attr_reader :changes, :mkdirs, :rmdirs

    def initialize(repository, tree_diff)
      @repo = repository
      @diff = tree_diff

      @changes = { :create => [], :update => [], :delete => [] }
      @mkdirs  = Set.new
      @rmdirs  = Set.new
    end

    def apply_changes
      plan_changes
      update_workspace
    end

    def blob_data(oid)
      @repo.database.load(oid).data
    end

    private

    def plan_changes
      @diff.each do |path, (old_item, new_item)|
        record_change(path, old_item, new_item)
      end
    end

    def update_workspace
      @repo.workspace.apply_migration(self)
    end

    def record_change(path, old_item, new_item)
      if old_item == nil
        @mkdirs.merge(path.dirname.descend)
        action = :create
      elsif new_item == nil
        @rmdirs.merge(path.dirname.descend)
        action = :delete
      else
        @mkdirs.merge(path.dirname.descend)
        action = :update
      end
      @changes[action].push([path, new_item])
    end

  end
end
