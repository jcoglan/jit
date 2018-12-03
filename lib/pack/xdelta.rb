module Pack
  class XDelta

    BLOCK_SIZE = 16

    def self.create_index(source)
      blocks = source.bytesize / BLOCK_SIZE
      index  = {}

      (0 ... blocks).each do |i|
        offset = i * BLOCK_SIZE
        slice  = source.byteslice(offset, BLOCK_SIZE)

        index[slice] ||= []
        index[slice].push(offset)
      end

      new(source, index)
    end

    def initialize(source, index)
      @source = source
      @index  = index
    end

    def compress(target)
      @target = target
      @offset = 0
      @insert = []
      @ops    = []

      generate_ops while @offset < @target.bytesize
      flush_insert

      @ops
    end

    private

    def generate_ops
      m_offset, m_size = longest_match
      return push_insert if m_size == 0

      m_offset, m_size = expand_match(m_offset, m_size)

      flush_insert
      @ops.push(Delta::Copy.new(m_offset, m_size))
    end

    def longest_match
      slice = @target.byteslice(@offset, BLOCK_SIZE)
      return [0, 0] unless @index.has_key?(slice)

      m_offset = m_size = 0

      @index[slice].each do |pos|
        remaining = remaining_bytes(pos)
        break if remaining <= m_size

        s = match_from(pos, remaining)
        next if m_size >= s - pos

        m_offset = pos
        m_size   = s - pos
      end

      [m_offset, m_size]
    end

    def remaining_bytes(pos)
      source_remaining = @source.bytesize - pos
      target_remaining = @target.bytesize - @offset

      [source_remaining, target_remaining, MAX_COPY_SIZE].min
    end

    def match_from(pos, remaining)
      s, t = pos, @offset

      while remaining > 0 and @source.getbyte(s) == @target.getbyte(t)
        s, t  = s + 1, t + 1
        remaining -= 1
      end

      s
    end

    def expand_match(m_offset, m_size)
      while m_offset > 0 and @source.getbyte(m_offset - 1) == @insert.last
        break if m_size == MAX_COPY_SIZE

        @offset  -= 1
        m_offset -= 1
        m_size   += 1

        @insert.pop
      end

      @offset += m_size
      [m_offset, m_size]
    end

    def push_insert
      @insert.push(@target.getbyte(@offset))
      @offset += 1
      flush_insert(MAX_INSERT_SIZE)
    end

    def flush_insert(size = nil)
      return if size and @insert.size < size
      return if @insert.empty?

      @ops.push(Delta::Insert.new(@insert.pack("C*")))
      @insert = []
    end

  end
end
