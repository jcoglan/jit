require_relative "./base"
require_relative "../rev_list"

module Command
  class RevList < Base

    def define_options
      @parser.on("--all")      { @options[:all]      = true }
      @parser.on("--branches") { @options[:branches] = true }
      @parser.on("--remotes")  { @options[:remotes]  = true }

      @parser.on("--ignore-missing") { @options[:missing] = true }
      @parser.on("--objects")        { @options[:objects] = true }
      @parser.on("--reverse")        { @options[:reverse] = true }

      @options[:walk] = true
      @parser.on("--do-walk") { @options[:walk] = true  }
      @parser.on("--no-walk") { @options[:walk] = false }
    end

    def run
      rev_list = ::RevList.new(repo, @args, @options)
      iterator = @options[:reverse] ? :reverse_each : :each

      rev_list.__send__(iterator) do |object, path|
        puts "#{ object.oid } #{ path }".strip
      end

      exit 0
    end

  end
end
