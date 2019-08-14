class Graph
  class Buffer

    attr_reader :data, :size

    def initialize
      @data = ""
      @size = 0
    end

    def write(string)
      @size += string.bytesize
      @data.concat(string)
    end

    def write_column(column, string)
      @size += string.bytesize

      color  = column.color
      string = Color.format(color, string) if color

      @data.concat(string)
    end

  end
end
