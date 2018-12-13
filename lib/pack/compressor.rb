require_relative "./delta"
require_relative "./window"

module Pack
  class Compressor

    OBJECT_SIZE = 50..0x20000000
    MAX_DEPTH   = 50
    WINDOW_SIZE = 8

    def initialize(database, progress)
      @database = database
      @window   = Window.new(WINDOW_SIZE)
      @progress = progress
      @objects  = []
    end

    def add(entry)
      return unless OBJECT_SIZE.include?(entry.size)
      @objects.push(entry)
    end

    def build_deltas
      @progress&.start("Compressing objects", @objects.size)

      @objects.sort! { |a, b| b.sort_key <=> a.sort_key }

      @objects.each do |entry|
        build_delta(entry)
        @progress&.tick
      end
      @progress&.stop
    end

    private

    def build_delta(entry)
      object = @database.load_raw(entry.oid)
      target = @window.add(entry, object.data)

      @window.each { |source| try_delta(source, target) }
    end

    def try_delta(source, target)
      return unless source.type == target.type
      return unless source.depth < MAX_DEPTH

      max_size = max_size_heuristic(source, target)
      return unless compatible_sizes?(source, target, max_size)

      delta = Delta.new(source, target)
      size  = target.entry.packed_size

      return if delta.size > max_size
      return if delta.size == size and delta.base.depth + 1 >= target.depth

      target.entry.assign_delta(delta)
    end

    def max_size_heuristic(source, target)
      if target.delta
        max_size  = target.delta.size
        ref_depth = target.depth
      else
        max_size  = target.size / 2 - 20
        ref_depth = 1
      end

      max_size * (MAX_DEPTH - source.depth) / (MAX_DEPTH + 1 - ref_depth)
    end

    def compatible_sizes?(source, target, max_size)
      size_diff = [target.size - source.size, 0].max

      return false if max_size == 0
      return false if size_diff >= max_size
      return false if target.size < source.size / 32

      true
    end

  end
end
