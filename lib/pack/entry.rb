require "forwardable"
require_relative "./numbers"

module Pack
  class Entry

    extend Forwardable
    def_delegators :@info, :type, :size

    attr_accessor :offset
    attr_reader :oid, :delta, :depth

    def initialize(oid, info, path, ofs = false)
      @oid   = oid
      @info  = info
      @path  = path
      @ofs   = ofs
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
      if @delta
        @ofs ? OFS_DELTA : REF_DELTA
      else
        TYPE_CODES.fetch(@info.type)
      end
    end

    def packed_size
      @delta ? @delta.size : @info.size
    end

    def delta_prefix
      return "" unless @delta

      if @ofs
        Numbers::VarIntBE.write(offset - @delta.base.offset)
      else
        [@delta.base.oid].pack("H40")
      end
    end

  end
end
