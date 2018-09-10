require_relative "./base"

module Command
  class Rm < Base

    def run
      repo.index.load_for_update
      @args.each { |path| remove_file(path) }
      repo.index.write_updates

      exit 0
    end

    private

    def remove_file(path)
      repo.index.remove(path)
      repo.workspace.remove(path)
      puts "rm '#{ path }'"
    end

  end
end
