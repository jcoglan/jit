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

      delta = Delta.new(source, target)
      size  = target.entry.packed_size

      return if delta.size > size
      return if delta.size == size and delta.base.depth + 1 >= target.depth

      target.entry.assign_delta(delta)
    end

  end
end
