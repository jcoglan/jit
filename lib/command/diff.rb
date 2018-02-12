require "pathname"
require_relative "./base"

module Command
  class Diff < Base

    def run
      repo.index.load
      @status = repo.status

      @status.workspace_changes.each do |path, state|
        case state
        when :modified then diff_file_modified(path)
        end
      end

      exit 0
    end

    private

    def diff_file_modified(path)
      entry  = repo.index.entry_for_path(path)
      a_oid  = entry.oid
      a_mode = entry.mode.to_s(8)
      a_path = Pathname.new("a").join(path)

      blob   = Database::Blob.new(repo.workspace.read_file(path))
      b_oid  = repo.database.hash_object(blob)
      b_path = Pathname.new("b").join(path)

      puts "diff --git #{ a_path } #{ b_path }"
      puts "index #{ short a_oid }..#{ short b_oid } #{ a_mode }"
      puts "--- #{ a_path }"
      puts "+++ #{ b_path }"
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

  end
end
