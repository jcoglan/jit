class Progress
  UNITS = ["B", "KiB", "MiB", "GiB"]
  SCALE = 1024.0

  def initialize(output)
    @output  = output
    @message = nil
  end

  def start(message, total = nil)
    return unless @output.isatty

    @message  = message
    @total    = total
    @count    = 0
    @bytes    = 0
    @write_at = get_time
  end

  def tick(bytes = 0)
    return unless @message

    @count += 1
    @bytes  = bytes

    current_time = get_time
    return if current_time < @write_at + 0.05
    @write_at = current_time

    clear_line
    @output.write(status_line)
  end

  def stop
    return unless @message

    @total = @count

    clear_line
    @output.puts(status_line)
    @message = nil
  end

  private

  def get_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def clear_line
    @output.write("\e[G\e[K")
  end

  def status_line
    line = "#{ @message }: #{ format_count }"

    line.concat(", #{ format_bytes }") if @bytes > 0
    line.concat(", done.") if @count == @total

    line
  end

  def format_count
    if @total
      percent = (@total == 0) ? 100 : 100 * @count / @total
      "#{ percent }% (#{ @count }/#{ @total })"
    else
      "(#{ @count })"
    end
  end

  def format_bytes
    power  = Math.log(@bytes, SCALE).floor
    scaled = @bytes / (SCALE ** power)

    format("%.2f #{ UNITS[power] }", scaled)
  end
end
