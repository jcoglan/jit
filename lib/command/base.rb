require "pathname"

require_relative "../display"
require_relative "../display/pager"
require_relative "../repository"

module Command
  class Base

    attr_reader :status

    def initialize(dir, env, args, stdin, stdout, stderr)
      @dir    = dir
      @env    = env
      @args   = args
      @stdin  = stdin
      @stdout = stdout
      @stderr = stderr

      @display = Display.new(stdout)
    end

    def execute
      catch(:exit) { run }
      @display.close
    end

    private

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join(".git"))
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def setup_pager
      return unless @display.isatty
      @display = Display::Pager.new(@display, @env)
    end

    def fmt(style, string)
      @display.fmt(style, string)
    end

    def puts(string)
      @display.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

  end
end
