require "pathname"
require_relative "./base"

module Command
  class Diff < Base

    NULL_OID  = "0" * 40
    NULL_PATH = "/dev/null"

    Target = Struct.new(:path, :oid, :mode) do
      def diff_path
        mode ? path : NULL_PATH
      end
    end

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
      a_mode = entry.mode

      blob   = Database::Blob.new(repo.workspace.read_file(path))
      b_oid  = repo.database.hash_object(blob)
      b_mode = Index::Entry.mode_for_stat(@status.stats[path])

      a = Target.new(path, a_oid, a_mode.to_s(8))
      b = Target.new(path, b_oid, b_mode.to_s(8))

      print_diff(a, b)
    end

    def diff_file_deleted(path)
      entry  = repo.index.entry_for_path(path)
      a_oid  = entry.oid
      a_mode = entry.mode

      a = Target.new(path, a_oid, a_mode.to_s(8))
      b = Target.new(path, NULL_OID, nil)

      print_diff(a, b)
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

    def print_diff(a, b)
      return if a.oid == b.oid and a.mode == b.mode

      a.path = Pathname.new("a").join(a.path)
      b.path = Pathname.new("b").join(b.path)

      puts "diff --git #{ a.path } #{ b.path }"
      print_diff_mode(a, b)
      print_diff_content(a, b)
    end

    def print_diff_mode(a, b)
      if b.mode == nil
        puts "deleted file mode #{ a.mode }"
      elsif a.mode != b.mode
        puts "old mode #{ a.mode }"
        puts "new mode #{ b.mode }"
      end
    end

    def print_diff_content(a, b)
      return if a.oid == b.oid

      oid_range = "index #{ short a.oid }..#{ short b.oid }"
      oid_range.concat(" #{ a.mode }") if a.mode == b.mode

      puts oid_range
      puts "--- #{ a.diff_path }"
      puts "+++ #{ b.diff_path }"
    end

  end
end
