class Remotes
  class Protocol

    attr_reader :input, :output

    def initialize(command, input, output, capabilities = [])
      @command = command
      @input   = input
      @output  = output

      @input.sync = @output.sync = true

      @caps_local  = capabilities
      @caps_remote = nil
      @caps_sent   = false
    end

    def capable?(ability)
      @caps_remote&.include?(ability)
    end

    def send_packet(line)
      return @output.write("0000") if line == nil

      line = append_caps(line)

      size = line.bytesize + 5
      @output.write(size.to_s(16).rjust(4, "0"))
      @output.write(line)
      @output.write("\n")
    end

    def recv_packet
      head = @input.read(4)
      return head unless /[0-9a-f]{4}/ =~ head

      size = head.to_i(16)
      return nil if size == 0

      line = @input.read(size - 4).sub(/\n$/, "")
      detect_caps(line)
    end

    def recv_until(terminator)
      loop do
        line = recv_packet
        break if line == terminator
        yield line
      end
    end

    private

    def append_caps(line)
      return line if @caps_sent
      @caps_sent = true

      sep   = (@command == "fetch") ? " " : "\0"
      caps  = @caps_local
      caps &= @caps_remote if @caps_remote

      line + sep + caps.join(" ")
    end

    def detect_caps(line)
      return line if @caps_remote

      if @command == "upload-pack"
        sep, n = " ", 3
      else
        sep, n = "\0", 2
      end

      parts = line.split(sep, n)
      caps  = (parts.size == n) ? parts.pop : ""

      @caps_remote = caps.split(/ +/)
      parts.join(" ")
    end

  end
end
