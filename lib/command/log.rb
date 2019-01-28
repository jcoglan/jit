require_relative "./base"
require_relative "./shared/print_diff"
require_relative "../rev_list"

module Command
  class Log < Base

    include PrintDiff

    def define_options
      @rev_list_opts = {}
      @parser.on("--all")      { @rev_list_opts[:all]      = true }
      @parser.on("--branches") { @rev_list_opts[:branches] = true }
      @parser.on("--remotes")  { @rev_list_opts[:remotes]  = true }

      @options[:decorate] = "auto"
      @options[:abbrev]   = :auto
      @options[:format]   = "medium"
      @options[:patch]    = false

      define_print_diff_options

      @parser.on "--decorate[=<format>]" do |format|
        @options[:decorate] = format || "short"
      end

      @parser.on "--no-decorate" do
        @options[:decorate] = "no"
      end

      @parser.on "--[no-]abbrev-commit" do |value|
        @options[:abbrev] = value
      end

      @parser.on "--pretty=<format>", "--format=<format>" do |format|
        @options[:format] = format
      end

      @parser.on "--oneline" do
        @options[:abbrev] = true if @options[:abbrev] == :auto
        @options[:format] = "oneline"
      end

      @parser.on "--cc" do
        @options[:combined] = @options[:patch] = true
      end
    end

    def run
      setup_pager

      @reverse_refs = repo.refs.reverse_refs
      @current_ref  = repo.refs.current_ref

      @rev_list = ::RevList.new(repo, @args, @rev_list_opts)
      @rev_list.each { |commit| show_commit(commit) }

      exit 0
    end

    private

    def blank_line
      return if @options[:format] == "oneline"
      puts "" if defined? @blank_line
      @blank_line = true
    end

    def show_commit(commit)
      case @options[:format]
      when "medium"  then show_commit_medium(commit)
      when "oneline" then show_commit_oneline(commit)
      end

      show_patch(commit)
    end

    def show_commit_medium(commit)
      author = commit.author

      blank_line
      puts fmt(:yellow, "commit #{ abbrev(commit) }") + decorate(commit)

      if commit.merge?
        oids = commit.parents.map { |oid| repo.database.short_oid(oid) }
        puts "Merge: #{ oids.join(" ") }"
      end

      puts "Author: #{ author.name } <#{ author.email }>"
      puts "Date:   #{ author.readable_time }"
      blank_line
      commit.message.each_line { |line| puts "    #{ line }" }
    end

    def show_commit_oneline(commit)
      id = fmt(:yellow, abbrev(commit)) + decorate(commit)
      puts "#{ id } #{ commit.title_line }"
    end

    def abbrev(commit)
      if @options[:abbrev] == true
        repo.database.short_oid(commit.oid)
      else
        commit.oid
      end
    end

    def decorate(commit)
      case @options[:decorate]
      when "auto" then return "" unless @isatty
      when "no"   then return ""
      end

      refs = @reverse_refs[commit.oid]
      return "" if refs.empty?

      head, refs = refs.partition { |ref| ref.head? and not @current_ref.head? }
      names = refs.map { |ref| decoration_name(head.first, ref) }

      fmt(:yellow, " (") + names.join(fmt(:yellow, ", ")) + fmt(:yellow, ")")
    end

    def decoration_name(head, ref)
      case @options[:decorate]
      when "short", "auto" then name = ref.short_name
      when "full"          then name = ref.path
      end

      name = fmt(ref_color(ref), name)

      if head and ref == @current_ref
        name = fmt(ref_color(head), "#{ head.path } -> #{ name }")
      end

      name
    end

    def ref_color(ref)
      return [:bold, :cyan]  if ref.head?
      return [:bold, :green] if ref.branch?
      return [:bold, :red]   if ref.remote?
    end

    def show_patch(commit)
      return unless @options[:patch]
      return show_merge_patch(commit) if commit.merge?

      diff  = @rev_list.tree_diff(commit.parent, commit.oid)
      paths = diff.keys.sort_by(&:to_s)

      blank_line

      paths.each do |path|
        old_item, new_item = diff[path]
        print_diff(from_diff_item(path, old_item), from_diff_item(path, new_item))
      end
    end

    def show_merge_patch(commit)
      return unless @options[:combined]

      diffs = commit.parents.map { |oid| @rev_list.tree_diff(oid, commit.oid) }

      paths = diffs.first.keys.select do |path|
        diffs.drop(1).all? { |diff| diff.has_key?(path) }
      end

      blank_line

      paths.each do |path|
        parents = diffs.map { |diff| from_diff_item(path, diff[path][0]) }
        child   = from_diff_item(path, diffs.first[path][1])

        print_combined_diff(parents, child)
      end
    end

    def from_diff_item(path, item)
      if item
        blob = repo.database.load(item.oid)
        Target.new(path, item.oid, item.mode.to_s(8), blob.data)
      else
        Target.new(path, NULL_OID, nil, "")
      end
    end

  end
end
