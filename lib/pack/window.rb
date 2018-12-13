require "forwardable"

module Pack
  class Window

    Unpacked = Struct.new(:entry, :data) do
      extend Forwardable
      def_delegators :entry, :type, :size, :delta, :depth

      attr_accessor :delta_index
    end

    def initialize(size)
      @objects = Array.new(size)
      @offset  = 0
    end

    def add(entry, data)
      unpacked = Unpacked.new(entry, data)
      @objects[@offset] = unpacked
      @offset = wrap(@offset + 1)

      unpacked
    end

    def each
      cursor = wrap(@offset - 2)
      limit  = wrap(@offset - 1)

      loop do
        break if cursor == limit

        unpacked = @objects[cursor]
        yield unpacked if unpacked

        cursor = wrap(cursor - 1)
      end
    end

    private

    def wrap(offset)
      offset % @objects.size
    end

  end
end
