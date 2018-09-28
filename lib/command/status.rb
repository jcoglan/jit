require_relative "./base"

module Command
  class Status < Base

    LABEL_WIDTH = 12

    LONG_STATUS = {
      :added    => "new file:",
      :deleted  => "deleted:",
      :modified => "modified:"
    }

    SHORT_STATUS = {
      :added    => "A",
      :deleted  => "D",
      :modified => "M"
    }

    CONFLICT_LABEL_WIDTH = 17

    CONFLICT_LONG_STATUS = {
      [1, 2, 3] => "both modified:",
      [1, 2]    => "deleted by them:",
      [1, 3]    => "deleted by us:",
      [2, 3]    => "both added:",
      [2]       => "added by us:",
      [3]       => "added by them:"
    }

    CONFLICT_SHORT_STATUS = {
      [1, 2, 3] => "UU",
      [1, 2]    => "UD",
      [1, 3]    => "DU",
      [2, 3]    => "AA",
      [2]       => "AU",
      [3]       => "UA"
    }

    UI_LABELS = { :normal => LONG_STATUS, :conflict => CONFLICT_LONG_STATUS }
    UI_WIDTHS = { :normal => LABEL_WIDTH, :conflict => CONFLICT_LABEL_WIDTH }

    def define_options
      @options[:format] = "long"
      @parser.on("--porcelain") { @options[:format] = "porcelain" }
    end

    def run
      repo.index.load_for_update
      @status = repo.status
      repo.index.write_updates

      print_results
      exit 0
    end

    private

    def print_results
      case @options[:format]
      when "long"      then print_long_format
      when "porcelain" then print_porcelain_format
      end
    end

    def print_long_format
      print_branch_status
      print_pending_commit_status

      print_changes("Changes to be committed", @status.index_changes, :green)
      print_changes("Unmerged paths", @status.conflicts, :red, :conflict)
      print_changes("Changes not staged for commit", @status.workspace_changes, :red)
      print_changes("Untracked files", @status.untracked_files, :red)

      print_commit_status
    end

    def print_branch_status
      current = repo.refs.current_ref

      if current.head?
        puts fmt(:red, "Not currently on any branch.")
      else
        puts "On branch #{ current.short_name }"
      end
    end

    def print_pending_commit_status
      case repo.pending_commit.merge_type
      when :merge
        if @status.conflicts.empty?
          puts "All conflicts fixed but you are still merging."
          hint "use 'jit commit' to conclude merge"
        else
          puts "You have unmerged paths."
          hint "fix conflicts and run 'jit commit'"
          hint "use 'jit merge --abort' to abort the merge"
        end
        puts ""
      when :cherry_pick
        print_pending_type(:cherry_pick)
      when :revert
        print_pending_type(:revert)
      end
    end

    def print_pending_type(merge_type)
      oid   = repo.pending_commit.merge_oid(merge_type)
      short = repo.database.short_oid(oid)
      op    = merge_type.to_s.sub("_", "-")

      puts "You are currently #{ op }ing commit #{ short }."

      if @status.conflicts.empty?
        hint "all conflicts fixed: run 'jit #{ op } --continue'"
      else
        hint "fix conflicts and run 'jit #{ op } --continue'"
      end
      hint "use 'jit #{ op } --abort' to cancel the #{ op } operation"
      puts ""
    end

    def hint(message)
      puts "  (#{ message })"
    end

    def print_changes(message, changeset, style, label_set = :normal)
      return if changeset.empty?

      labels = UI_LABELS[label_set]
      width  = UI_WIDTHS[label_set]

      puts "#{ message }:"
      puts ""
      changeset.each do |path, type|
        status = type ? labels[type].ljust(width, " ") : ""
        puts "\t" + fmt(style, status + path)
      end
      puts ""
    end

    def print_commit_status
      return if @status.index_changes.any?

      if @status.workspace_changes.any?
        puts "no changes added to commit"
      elsif @status.untracked_files.any?
        puts "nothing added to commit but untracked files present"
      else
        puts "nothing to commit, working tree clean"
      end
    end

    def print_porcelain_format
      @status.changed.each do |path|
        status = status_for(path)
        puts "#{ status } #{ path }"
      end

      @status.untracked_files.each do |path|
        puts "?? #{ path }"
      end
    end

    def status_for(path)
      if @status.conflicts.has_key?(path)
        CONFLICT_SHORT_STATUS[@status.conflicts[path]]
      else
        left  = SHORT_STATUS.fetch(@status.index_changes[path], " ")
        right = SHORT_STATUS.fetch(@status.workspace_changes[path], " ")
        left + right
      end
    end

  end
end
