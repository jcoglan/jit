require "pathname"
require_relative "../../diff"

module Command
  module PrintDiff

    DIFF_FORMATS = {
      :context => :normal,
      :meta    => :bold,
      :frag    => :cyan,
      :old     => :red,
      :new     => :green
    }

    NULL_OID  = "0" * 40
    NULL_PATH = "/dev/null"

    Target = Struct.new(:path, :oid, :mode, :data) do
      def diff_path
        mode ? path : NULL_PATH
      end
    end

    def define_print_diff_options
      @parser.on("-p", "-u", "--patch") { @options[:patch] = true  }
      @parser.on("-s", "--no-patch")    { @options[:patch] = false }
    end

    private

    def diff_fmt(name, text)
      key   = ["color", "diff", name]
      style = repo.config.get(key)&.split(/ +/) || DIFF_FORMATS.fetch(name)

      fmt(style, text)
    end

    def header(string)
      puts diff_fmt(:meta, string)
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

    def print_diff(a, b)
      return if a.oid == b.oid and a.mode == b.mode

      a.path = Pathname.new("a").join(a.path)
      b.path = Pathname.new("b").join(b.path)

      header("diff --git #{ a.path } #{ b.path }")
      print_diff_mode(a, b)
      print_diff_content(a, b)
    end

    def print_diff_mode(a, b)
      if a.mode == nil
        header("new file mode #{ b.mode }")
      elsif b.mode == nil
        header("deleted file mode #{ a.mode }")
      elsif a.mode != b.mode
        header("old mode #{ a.mode }")
        header("new mode #{ b.mode }")
      end
    end

    def print_diff_content(a, b)
      return if a.oid == b.oid

      oid_range = "index #{ short a.oid }..#{ short b.oid }"
      oid_range.concat(" #{ a.mode }") if a.mode == b.mode

      header(oid_range)
      header("--- #{ a.diff_path }")
      header("+++ #{ b.diff_path }")

      hunks = ::Diff.diff_hunks(a.data, b.data)
      hunks.each { |hunk| print_diff_hunk(hunk) }
    end

    def print_combined_diff(as, b)
      header("diff --cc #{ b.path }")

      a_oids = as.map { |a| short a.oid }
      oid_range = "index #{ a_oids.join(",") }..#{ short b.oid }"
      header(oid_range)

      unless as.all? { |a| a.mode == b.mode }
        header("mode #{ as.map(&:mode).join(",") }..#{ b.mode }")
      end

      header("--- a/#{ b.diff_path }")
      header("+++ b/#{ b.diff_path }")

      hunks = ::Diff.combined_hunks(as.map(&:data), b.data)
      hunks.each { |hunk| print_diff_hunk(hunk) }
    end

    def print_diff_hunk(hunk)
      puts diff_fmt(:frag, hunk.header)
      hunk.edits.each { |edit| print_diff_edit(edit) }
    end

    def print_diff_edit(edit)
      text = edit.to_s.rstrip

      case edit.type
      when :eql then puts diff_fmt(:context, text)
      when :ins then puts diff_fmt(:new, text)
      when :del then puts diff_fmt(:old, text)
      end
    end

  end
end
