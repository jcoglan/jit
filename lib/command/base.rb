require "pathname"

require_relative "../color"
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
    end

    def execute
      catch(:exit) { run }
    end

    private

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join(".git"))
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def fmt(style, string)
      @stdout.isatty ? Color.format(style, string) : string
    end

    def puts(string)
      @stdout.puts(string)
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

  end
end
