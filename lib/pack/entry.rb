require "forwardable"

module Pack
  class Entry

    extend Forwardable
    def_delegators :@info, :type, :size

    attr_reader :oid, :delta, :depth

    def initialize(oid, info, path)
      @oid   = oid
      @info  = info
      @path  = path
      @delta = nil
      @depth = 0
    end

    def sort_key
      [packed_type, @path&.basename, @path&.dirname, @info.size]
    end

    def assign_delta(delta)
      @delta = delta
      @depth = delta.base.depth + 1
    end

    def packed_type
      @delta ? REF_DELTA : TYPE_CODES.fetch(@info.type)
    end

    def packed_size
      @delta ? @delta.size : @info.size
    end

    def delta_prefix
      @delta ? [@delta.base.oid].pack("H40") : ""
    end

  end
end
