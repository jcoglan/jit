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

      if @args.first == "--cached"
        diff_head_index
      else
        diff_index_workspace
      end

      exit 0
    end

    private

    def diff_head_index
      @status.index_changes.each do |path, state|
        case state
        when :added    then print_diff(from_nothing(path), from_index(path))
        when :modified then print_diff(from_head(path), from_index(path))
        when :deleted  then print_diff(from_head(path), from_nothing(path))
        end
      end
    end

    def diff_index_workspace
      @status.workspace_changes.each do |path, state|
        case state
        when :modified then print_diff(from_index(path), from_file(path))
        when :deleted  then print_diff(from_index(path), from_nothing(path))
        end
      end
    end

    def from_head(path)
      entry = @status.head_tree.fetch(path)
      from_entry(path, entry)
    end

    def from_index(path)
      entry = repo.index.entry_for_path(path)
      from_entry(path, entry)
    end

    def from_entry(path, entry)
      Target.new(path, entry.oid, entry.mode.to_s(8))
    end

    def from_file(path)
      blob = Database::Blob.new(repo.workspace.read_file(path))
      oid  = repo.database.hash_object(blob)
      mode = Index::Entry.mode_for_stat(@status.stats[path])

      Target.new(path, oid, mode.to_s(8))
    end

    def from_nothing(path)
      Target.new(path, NULL_OID, nil)
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
      if a.mode == nil
        puts "new file mode #{ b.mode }"
      elsif b.mode == nil
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
