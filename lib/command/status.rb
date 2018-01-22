require "set"
require_relative "./base"

module Command
  class Status < Base

    def run
      repo.index.load

      @untracked = SortedSet.new

      scan_workspace

      @untracked.each { |path| puts "?? #{ path }" }

      exit 0
    end

    private

    def scan_workspace(prefix = nil)
      repo.workspace.list_dir(prefix).each do |path, stat|
        if repo.index.tracked?(path)
          scan_workspace(path) if stat.directory?
        else
          path += File::SEPARATOR if stat.directory?
          @untracked.add(path)
        end
      end
    end

  end
end
