require_relative "./diff3"

module Merge
  class Resolve

    def initialize(repository, inputs)
      @repo   = repository
      @inputs = inputs

      @on_progress = nil
    end

    def on_progress(&block)
      @on_progress = block
    end

    def execute
      prepare_tree_diffs

      migration = @repo.migration(@clean_diff)
      migration.apply_changes

      add_conflicts_to_index
      write_untracked_files
    end

    private

    def prepare_tree_diffs
      base_oid    = @inputs.base_oids.first
      @left_diff  = @repo.database.tree_diff(base_oid, @inputs.left_oid)
      @right_diff = @repo.database.tree_diff(base_oid, @inputs.right_oid)
      @clean_diff = {}
      @conflicts  = {}
      @untracked  = {}

      @right_diff.each do |path, (old_item, new_item)|
        file_dir_conflict(path, @left_diff, @inputs.left_name) if new_item
        same_path_conflict(path, old_item, new_item)
      end

      @left_diff.each do |path, (_, new_item)|
        file_dir_conflict(path, @right_diff, @inputs.right_name) if new_item
      end
    end

    def same_path_conflict(path, base, right)
      return if @conflicts[path]

      unless @left_diff.has_key?(path)
        @clean_diff[path] = [base, right]
        return
      end

      left = @left_diff[path][1]
      return if left == right

      log "Auto-merging #{ path }" if left and right

      oid_ok, oid = merge_blobs(base&.oid, left&.oid, right&.oid)
      mode_ok, mode = merge_modes(base&.mode, left&.mode, right&.mode)

      @clean_diff[path] = [left, Database::Entry.new(oid, mode)]
      return if oid_ok and mode_ok

      @conflicts[path] = [base, left, right]
      log_conflict(path)
    end

    def merge_blobs(base_oid, left_oid, right_oid)
      result = merge3(base_oid, left_oid, right_oid)
      return result if result

      oids  = [base_oid, left_oid, right_oid]
      blobs = oids.map { |oid| oid ? @repo.database.load(oid).data : "" }
      merge = Diff3.merge(*blobs)

      data = merge.to_s(@inputs.left_name, @inputs.right_name)
      blob = Database::Blob.new(data)
      @repo.database.store(blob)

      [merge.clean?, blob.oid]
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

    def file_dir_conflict(path, diff, name)
      path.dirname.ascend do |parent|
        old_item, new_item = diff[parent]
        next unless new_item

        @conflicts[parent] = case name
          when @inputs.left_name  then [old_item, new_item, nil]
          when @inputs.right_name then [old_item, nil, new_item]
        end

        @clean_diff.delete(parent)
        rename = "#{ parent }~#{ name }"
        @untracked[rename] = new_item

        log "Adding #{ path }" unless diff[path]
        log_conflict(parent, rename)
      end
    end

    def add_conflicts_to_index
      @conflicts.each do |path, items|
        @repo.index.add_conflict_set(path, items)
      end
    end

    def write_untracked_files
      @untracked.each do |path, item|
        blob = @repo.database.load(item.oid)
        @repo.workspace.write_file(path, blob.data)
      end
    end

    def log(message)
      @on_progress&.call(message)
    end

    def log_conflict(path, rename = nil)
      base, left, right = @conflicts[path]

      if left and right
        log_left_right_conflict(path)
      elsif base and (left or right)
        log_modify_delete_conflict(path, rename)
      else
        log_file_directory_conflict(path, rename)
      end
    end

    def log_left_right_conflict(path)
      type = @conflicts[path][0] ? "content" : "add/add"
      log "CONFLICT (#{ type }): Merge conflict in #{ path }"
    end

    def log_modify_delete_conflict(path, rename)
      deleted, modified = log_branch_names(path)

      rename = rename ? " at #{ rename }" : ""

      log "CONFLICT (modify/delete): #{ path } " +
          "deleted in #{ deleted } and modified in #{ modified }. " +
          "Version #{ modified } of #{ path } left in tree#{ rename }."
    end

    def log_file_directory_conflict(path, rename)
      type = @conflicts[path][1] ? "file/directory" : "directory/file"
      branch, _ = log_branch_names(path)

      log "CONFLICT (#{ type }): There is a directory " +
          "with name #{ path } in #{ branch }. " +
          "Adding #{ path } as #{ rename }"
    end

    def log_branch_names(path)
      a, b = @inputs.left_name, @inputs.right_name
      @conflicts[path][1] ? [b, a] : [a, b]
    end

  end
end
