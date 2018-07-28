require_relative "./base"
require_relative "./shared/print_diff"

module Command
  class Diff < Base

    include PrintDiff

    def define_options
      @options[:patch] = true
      define_print_diff_options

      @parser.on "--cached", "--staged" do
        @options[:cached] = true
      end

      @parser.on("-1", "--base")   { @options[:stage] = 1 }
      @parser.on("-2", "--ours")   { @options[:stage] = 2 }
      @parser.on("-3", "--theirs") { @options[:stage] = 3 }
    end

    def run
      repo.index.load
      @status = repo.status

      setup_pager

      if @options[:cached]
        diff_head_index
      elsif @args.size == 2
        diff_commits
      else
        diff_index_workspace
      end

      exit 0
    end

    private

    def diff_commits
      return unless @options[:patch]

      a, b = @args.map { |rev| Revision.new(repo, rev).resolve }
      print_commit_diff(a, b)
    end

    def diff_head_index
      return unless @options[:patch]

      @status.index_changes.each do |path, state|
        case state
        when :added    then print_diff(from_nothing(path), from_index(path))
        when :modified then print_diff(from_head(path), from_index(path))
        when :deleted  then print_diff(from_head(path), from_nothing(path))
        end
      end
    end

    def diff_index_workspace
      return unless @options[:patch]

      paths = @status.conflicts.keys + @status.workspace_changes.keys

      paths.sort.each do |path|
        if @status.conflicts.has_key?(path)
          print_conflict_diff(path)
        else
          print_workspace_diff(path)
        end
      end
    end

    def print_conflict_diff(path)
      targets = (0..3).map { |stage| from_index(path, stage) }
      left, right = targets[2], targets[3]

      if @options[:stage]
        puts "* Unmerged path #{ path }"
        print_diff(targets[@options[:stage]], from_file(path))
      elsif left and right
        print_combined_diff([left, right], from_file(path))
      else
        puts "* Unmerged path #{ path }"
      end
    end

    def print_workspace_diff(path)
      case @status.workspace_changes[path]
      when :modified then print_diff(from_index(path), from_file(path))
      when :deleted  then print_diff(from_index(path), from_nothing(path))
      end
    end

    def from_head(path)
      entry = @status.head_tree.fetch(path)
      from_entry(path, entry)
    end

    def from_index(path, stage = 0)
      entry = repo.index.entry_for_path(path, stage)
      entry ? from_entry(path, entry) : nil
    end

    def from_file(path)
      blob = Database::Blob.new(repo.workspace.read_file(path))
      oid  = repo.database.hash_object(blob)
      mode = Index::Entry.mode_for_stat(@status.stats[path])

      Target.new(path, oid, mode.to_s(8), blob.data)
    end

  end
end
