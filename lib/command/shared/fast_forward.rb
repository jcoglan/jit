require_relative "../../merge/common_ancestors"

module Command
  module FastForward

    def fast_forward_error(old_oid, new_oid)
      return nil unless old_oid and new_oid
      return "fetch first" unless repo.database.has?(old_oid)
      return "non-fast-forward" unless fast_forward?(old_oid, new_oid)
    end

    def fast_forward?(old_oid, new_oid)
      common = ::Merge::CommonAncestors.new(repo.database, old_oid, [new_oid])
      common.find
      common.marked?(old_oid, :parent2)
    end

  end
end
