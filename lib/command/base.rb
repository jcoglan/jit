require "optparse"
require "pathname"

require_relative "../display"
require_relative "../display/pager"
require_relative "../editor"
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
      parse_options
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

    def parse_options
      @options = {}
      @parser  = OptionParser.new

      define_options
      @parser.parse!(@args)
    end

    def define_options
    end

    def setup_pager
      return unless @display.isatty
      @display = Display::Pager.new(@display, @env)
    end

    def edit_file(path)
      Editor.edit(path, editor_command) do |editor|
        yield editor
        editor.close unless @display.isatty
      end
    end

    def editor_command
      core_editor = repo.config.get(["core", "editor"])
      @env["GIT_EDITOR"] || core_editor || @env["VISUAL"] || @env["EDITOR"]
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
