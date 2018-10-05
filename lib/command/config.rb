require_relative "./base"

module Command
  class Config < Base

    def define_options
      @parser.on("--local")  { @options[:file] = :local  }
      @parser.on("--global") { @options[:file] = :global }
      @parser.on("--system") { @options[:file] = :system }

      @parser.on "-f <config-file>", "--file=<config-file>" do |file|
        @options[:file] = file
      end

      @parser.on("--add <name>")         { |name| @options[:add]     = name }
      @parser.on("--replace-all <name>") { |name| @options[:replace] = name }
      @parser.on("--get-all <name>")     { |name| @options[:get_all] = name }

      @parser.on "--remove-section <name>" do |name|
        @options[:remove_section] = name
      end
    end

    def run
      add_variable     if @options[:add]
      replace_variable if @options[:replace]
      get_all_values   if @options[:get_all]
      remove_section   if @options[:remove_section]

      key, value = parse_key(@args[0]), @args[1]

      if value
        edit_config { |config| config.set(key, value) }
      else
        read_config { |config| [*config.get(key)] }
      end

    rescue ::Config::ParseError => error
      @stderr.puts "error: #{ error.message }"
      exit 3
    end

    private

    def add_variable
      key = parse_key(@options[:add])
      edit_config { |config| config.add(key, @args[0]) }
    end

    def replace_variable
      key = parse_key(@options[:replace])
      edit_config { |config| config.replace_all(key, @args[0]) }
    end

    def remove_section
      key = @options[:remove_section].split(".", 2)
      edit_config { |config| config.remove_section(key) }
    end

    def get_all_values
      key = parse_key(@options[:get_all])
      read_config { |config| config.get_all(key) }
    end

    def read_config
      config = repo.config
      config = config.file(@options[:file]) if @options[:file]

      config.open
      values = yield config

      exit 1 if values.empty?

      values.each { |value| puts value }
      exit 0
    end

    def edit_config
      config = repo.config.file(@options.fetch(:file, :local))
      config.open_for_update
      yield config
      config.save

      exit 0

    rescue ::Config::Conflict => error
      @stderr.puts "error: #{ error.message }"
      exit 5
    end

    def parse_key(name)
      section, *subsection, var = name.split(".")

      unless var
        @stderr.puts "error: key does not contain a section: #{ name }"
        exit 2
      end

      unless ::Config.valid_key?([section, var])
        @stderr.puts "error: invalid key: #{ name }"
        exit 1
      end

      if subsection.empty?
        [section, var]
      else
        [section, subsection.join("."), var]
      end
    end

  end
end
