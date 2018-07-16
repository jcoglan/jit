module Merge
  class Resolve

    def initialize(repository, inputs)
      @repo   = repository
      @inputs = inputs
    end

    def execute
      base_oid  = @inputs.base_oids.first
      tree_diff = @repo.database.tree_diff(base_oid, @inputs.right_oid)
      migration = @repo.migration(tree_diff)

      migration.apply_changes
    end

  end
end
