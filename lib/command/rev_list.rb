require_relative "./base"
require_relative "../rev_list"

module Command
  class RevList < Base

    def define_options
      @parser.on("--all")     { @options[:all]     = true }
      @parser.on("--objects") { @options[:objects] = true }

      @options[:walk] = true
      @parser.on("--do-walk") { @options[:walk] = true  }
      @parser.on("--no-walk") { @options[:walk] = false }
    end

    def run
      rev_list = ::RevList.new(repo, @args, @options)
      rev_list.each { |object| puts object.oid }

      exit 0
    end

  end
end
