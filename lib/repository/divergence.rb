require_relative "../merge/common_ancestors"

class Repository
  class Divergence

    attr_reader :upstream, :ahead, :behind

    def initialize(repo, ref)
      @upstream = repo.remotes.get_upstream(ref.short_name)
      return unless @upstream

      left   = ref.read_oid
      right  = repo.refs.read_ref(@upstream)
      common = Merge::CommonAncestors.new(repo.database, left, [right])

      common.find
      @ahead, @behind = common.counts
    end

  end
end
