require_relative "./base"

module Command
  class Status < Base

    def run
      repo.workspace.list_files.sort.each do |path|
        puts "?? #{ path }"
      end

      exit 0
    end

  end
end
