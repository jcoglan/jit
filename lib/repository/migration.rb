require "set"
require_relative "./inspector"

class Repository
  class Migration

    Conflict = Class.new(StandardError)

    MESSAGES = {
      :stale_file => [
        "Your local changes to the following files would be overwritten by checkout:",
        "Please commit your changes or stash them before you switch branches."
      ],
      :stale_directory => [
        "Updating the following directories would lose untracked files in them:",
        "\n"
      ],
      :untracked_overwritten => [
        "The following untracked working tree files would be overwritten by checkout:",
        "Please move or remove them before you switch branches."
      ],
      :untracked_removed => [
        "The following untracked working tree files would be removed by checkout:",
        "Please move or remove them before you switch branches."
      ]
    }

    attr_reader :changes, :mkdirs, :rmdirs, :errors

    def initialize(repository, tree_diff)
      @repo = repository
      @diff = tree_diff

      @inspector = Inspector.new(repository)

      @changes = { :create => [], :update => [], :delete => [] }
      @mkdirs  = Set.new
      @rmdirs  = Set.new
      @errors  = []

      @conflicts = {
        :stale_file            => SortedSet.new,
        :stale_directory       => SortedSet.new,
        :untracked_overwritten => SortedSet.new,
        :untracked_removed     => SortedSet.new
      }
    end

    def apply_changes
      plan_changes
      update_workspace
      update_index
    end

    def blob_data(oid)
      @repo.database.load(oid).data
    end

    private

    def plan_changes
      @diff.each do |path, (old_item, new_item)|
        check_for_conflict(path, old_item, new_item)
        record_change(path, old_item, new_item)
      end

      collect_errors
    end

    def update_workspace
      @repo.workspace.apply_migration(self)
    end

    def update_index
      @changes[:delete].each do |path, _|
        @repo.index.remove(path)
      end

      [:create, :update].each do |action|
        @changes[action].each do |path, entry|
          stat = @repo.workspace.stat_file(path)
          @repo.index.add(path, entry.oid, stat)
        end
      end
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

    def check_for_conflict(path, old_item, new_item)
      entry = @repo.index.entry_for_path(path)

      if index_differs_from_trees(entry, old_item, new_item)
        @conflicts[:stale_file].add(path.to_s)
        return
      end

      stat = @repo.workspace.stat_file(path)
      type = get_error_type(stat, entry, new_item)

      if stat == nil
        parent = untracked_parent(path)
        @conflicts[type].add(entry ? path.to_s : parent.to_s) if parent

      elsif stat.file?
        changed = @inspector.compare_index_to_workspace(entry, stat)
        @conflicts[type].add(path.to_s) if changed

      elsif stat.directory?
        trackable = @inspector.trackable_file?(path, stat)
        @conflicts[type].add(path.to_s) if trackable
      end
    end

    def get_error_type(stat, entry, item)
      if entry
        :stale_file
      elsif stat&.directory?
        :stale_directory
      elsif item
        :untracked_overwritten
      else
        :untracked_removed
      end
    end

    def index_differs_from_trees(entry, old_item, new_item)
      @inspector.compare_tree_to_index(old_item, entry) and
      @inspector.compare_tree_to_index(new_item, entry)
    end

    def untracked_parent(path)
      path.dirname.ascend.find do |parent|
        next if parent.to_s == "."

        parent_stat = @repo.workspace.stat_file(parent)
        next unless parent_stat&.file?

        @inspector.trackable_file?(parent, parent_stat)
      end
    end

    def collect_errors
      @conflicts.each do |type, paths|
        next if paths.empty?

        lines = paths.map { |name| "\t#{ name }" }
        header, footer = MESSAGES.fetch(type)

        @errors.push([header, *lines, footer].join("\n"))
      end

      raise Conflict unless @errors.empty?
    end

  end
end
