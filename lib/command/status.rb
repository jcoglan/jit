require_relative "./base"

module Command
  class Status < Base

    def run
      repo.index.load

      untracked = repo.workspace.list_files.reject do |path|
        repo.index.tracked?(path)
      end

      untracked.sort.each do |path|
        puts "?? #{ path }"
      end

      exit 0
    end

  end
end
