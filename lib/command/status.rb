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

      print_changes("Changes to be committed", @status.index_changes, :green)
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

    def print_changes(message, changeset, style)
      return if changeset.empty?

      puts "#{ message }:"
      puts ""
      changeset.each do |path, type|
        status = type ? LONG_STATUS[type].ljust(LABEL_WIDTH, " ") : ""
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
      left  = SHORT_STATUS.fetch(@status.index_changes[path], " ")
      right = SHORT_STATUS.fetch(@status.workspace_changes[path], " ")

      left + right
    end

  end
end
