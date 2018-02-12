require "pathname"
require_relative "./base"

module Command
  class Diff < Base

    NULL_OID  = "0" * 40
    NULL_PATH = "/dev/null"

    def run
      repo.index.load
      @status = repo.status

      @status.workspace_changes.each do |path, state|
        case state
        when :modified then diff_file_modified(path)
        when :deleted  then diff_file_deleted(path)
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
      b_mode = Index::Entry.mode_for_stat(@status.stats[path]).to_s(8)
      b_path = Pathname.new("b").join(path)

      puts "diff --git #{ a_path } #{ b_path }"

      unless a_mode == b_mode
        puts "old mode #{ a_mode }"
        puts "new mode #{ b_mode }"
      end

      return if a_oid == b_oid

      oid_range = "index #{ short a_oid }..#{ short b_oid }"
      oid_range.concat(" #{ a_mode }") if a_mode == b_mode

      puts oid_range
      puts "--- #{ a_path }"
      puts "+++ #{ b_path }"
    end

    def diff_file_deleted(path)
      entry  = repo.index.entry_for_path(path)
      a_oid  = entry.oid
      a_mode = entry.mode.to_s(8)
      a_path = Pathname.new("a").join(path)

      b_oid  = NULL_OID
      b_path = Pathname.new("b").join(path)

      puts "diff --git #{ a_path } #{ b_path }"
      puts "deleted file mode #{ a_mode }"
      puts "index #{ short a_oid }..#{ short b_oid }"
      puts "--- #{ a_path }"
      puts "+++ #{ NULL_PATH }"
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

  end
end
