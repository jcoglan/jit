require "fileutils"
require_relative "./base"

module Command
  class Init < Base

    def run
      path = @args.fetch(0, @dir)

      root_path = expanded_pathname(path)
      git_path  = root_path.join(".git")

      ["objects", "refs"].each do |dir|
        begin
          FileUtils.mkdir_p(git_path.join(dir))
        rescue Errno::EACCES => error
          @stderr.puts "fatal: #{ error.message }"
          exit 1
        end
      end

      puts "Initialized empty Jit repository in #{ git_path }"
      exit 0
    end

  end
end
