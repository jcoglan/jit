module Merge
  class Resolve

    def initialize(repository, inputs)
      @repo   = repository
      @inputs = inputs
    end

    def execute
      prepare_tree_diffs

      migration = @repo.migration(@clean_diff)
      migration.apply_changes

      add_conflicts_to_index
    end

    private

    def prepare_tree_diffs
      base_oid    = @inputs.base_oids.first
      @left_diff  = @repo.database.tree_diff(base_oid, @inputs.left_oid)
      @right_diff = @repo.database.tree_diff(base_oid, @inputs.right_oid)
      @clean_diff = {}
      @conflicts  = {}

      @right_diff.each do |path, (old_item, new_item)|
        same_path_conflict(path, old_item, new_item)
      end
    end

    def same_path_conflict(path, base, right)
      unless @left_diff.has_key?(path)
        @clean_diff[path] = [base, right]
        return
      end

      left = @left_diff[path][1]
      return if left == right

      oid_ok, oid = merge_blobs(base&.oid, left&.oid, right&.oid)
      mode_ok, mode = merge_modes(base&.mode, left&.mode, right&.mode)

      @clean_diff[path] = [left, Database::Entry.new(oid, mode)]
      @conflicts[path] = [base, left, right] unless oid_ok and mode_ok
    end

    def merge_blobs(base_oid, left_oid, right_oid)
      result = merge3(base_oid, left_oid, right_oid)
      return result if result

      blob = Database::Blob.new(merged_data(left_oid, right_oid))
      @repo.database.store(blob)
      [false, blob.oid]
    end

    def merged_data(left_oid, right_oid)
      left_blob  = @repo.database.load(left_oid)
      right_blob = @repo.database.load(right_oid)

      [
        "<<<<<<< #{ @inputs.left_name }\n",
        left_blob.data,
        "=======\n",
        right_blob.data,
        ">>>>>>> #{ @inputs.right_name }\n"
      ].join("")
    end

    def merge_modes(base_mode, left_mode, right_mode)
      merge3(base_mode, left_mode, right_mode) || [false, left_mode]
    end

    def merge3(base, left, right)
      return [false, right] unless left
      return [false, left] unless right

      if left == base or left == right
        [true, right]
      elsif right == base
        [true, left]
      end
    end

    def add_conflicts_to_index
      @conflicts.each do |path, items|
        @repo.index.add_conflict_set(path, items)
      end
    end

  end
end
