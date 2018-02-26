require "pathname"

require_relative "../color"
require_relative "../pager"
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

      @isatty = @stdout.isatty
    end

    def execute
      catch(:exit) { run }

      if defined? @pager
        @stdout.close_write
        @pager.wait
      end
    end

    private

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join(".git"))
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def setup_pager
      return if defined? @pager
      return unless @isatty

      @pager  = Pager.new(@env, @stdout, @stderr)
      @stdout = @pager.input
    end

    def fmt(style, string)
      @isatty ? Color.format(style, string) : string
    end

    def puts(string)
      @stdout.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

  end
end
