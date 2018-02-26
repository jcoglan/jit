require "forwardable"

class Display
  class Pager

    PAGER_CMD = "less"
    PAGER_ENV = { "LESS" => "FRX", "LV" => "-c" }

    extend Forwardable
    def_delegators :@display, :isatty, :fmt, :stdout

    def initialize(display, env = {})
      @display = display
      start_pager_process(env)
    end

    def puts(string)
      @input.puts(string)
    end

    def close
      @input.close_write
      Process.waitpid(@pid)
    end

    private

    def start_pager_process(env)
      env = PAGER_ENV.merge(env)
      cmd = env["GIT_PAGER"] || env["PAGER"] || PAGER_CMD

      reader, writer = IO.pipe
      options = { :in => reader, :out => @display.stdout }

      @pid   = Process.spawn(env, cmd, options)
      @input = writer

      reader.close
    end

  end
end
