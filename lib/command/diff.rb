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
    end

    def run
      repo.index.load
      @status = repo.status

      setup_pager

      if @options[:cached]
        diff_head_index
      else
        diff_index_workspace
      end

      exit 0
    end

    private

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
      puts "* Unmerged path #{ path }"
    end

    def print_workspace_diff(path)
      case @status.workspace_changes[path]
      when :modified then print_diff(from_index(path), from_file(path))
      when :deleted  then print_diff(from_index(path), from_nothing(path))
      end
    end

    def from_head(path)
      entry = @status.head_tree.fetch(path)
      blob  = repo.database.load(entry.oid)

      Target.new(path, entry.oid, entry.mode.to_s(8), blob.data)
    end

    def from_index(path)
      entry = repo.index.entry_for_path(path)
      blob  = repo.database.load(entry.oid)

      Target.new(path, entry.oid, entry.mode.to_s(8), blob.data)
    end

    def from_file(path)
      blob = Database::Blob.new(repo.workspace.read_file(path))
      oid  = repo.database.hash_object(blob)
      mode = Index::Entry.mode_for_stat(@status.stats[path])

      Target.new(path, oid, mode.to_s(8), blob.data)
    end

    def from_nothing(path)
      Target.new(path, NULL_OID, nil, "")
    end

  end
end
