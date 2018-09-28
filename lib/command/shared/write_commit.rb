module Command
  module WriteCommit

    CONFLICT_MESSAGE = <<~MSG
      hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
      hint: as appropriate to mark resolution and make a commit.
      fatal: Exiting because of an unresolved conflict.
    MSG

    MERGE_NOTES = <<~MSG

      It looks like you may be committing a merge.
      If this is not correct, please remove the file
      \t.git/MERGE_HEAD
      and try again.
    MSG

    CHERRY_PICK_NOTES = <<~MSG

      It looks like you may be committing a cherry-pick.
      If this is not correct, please remove the file
      \t.git/CHERRY_PICK_HEAD
      and try again.
    MSG

    def define_write_commit_options
      @options[:edit] = :auto
      @parser.on("-e", "--[no-]edit") { |value| @options[:edit] = value }

      @parser.on "-m <message>", "--message=<message>" do |message|
        @options[:message] = message
        @options[:edit]    = false if @options[:edit] == :auto
      end

      @parser.on "-F <file>", "--file=<file>" do |file|
        @options[:file] = expanded_pathname(file)
        @options[:edit] = false if @options[:edit] == :auto
      end
    end

    def read_message
      if @options.has_key?(:message)
        "#{ @options[:message] }\n"
      elsif @options.has_key?(:file)
        File.read(@options[:file])
      end
    end

    def write_commit(parents, message)
      unless message
        @stderr.puts "Aborting commit due to empty commit message."
        exit 1
      end

      tree   = write_tree
      author = current_author
      commit = Database::Commit.new(parents, tree.oid, author, author, message)

      repo.database.store(commit)
      repo.refs.update_head(commit.oid)

      commit
    end

    def write_tree
      root = Database::Tree.build(repo.index.each_entry)
      root.traverse { |tree| repo.database.store(tree) }
      root
    end

    def current_author
      name  = @env.fetch("GIT_AUTHOR_NAME")
      email = @env.fetch("GIT_AUTHOR_EMAIL")

      Database::Author.new(name, email, Time.now)
    end

    def print_commit(commit)
      ref  = repo.refs.current_ref
      info = ref.head? ? "detached HEAD" : ref.short_name
      oid  = repo.database.short_oid(commit.oid)

      info.concat(" (root-commit)") unless commit.parent
      info.concat(" #{ oid }")

      puts "[#{ info }] #{ commit.title_line }"
    end

    def pending_commit
      @pending_commit ||= repo.pending_commit
    end

    def resume_merge(type)
      case type
      when :merge       then write_merge_commit
      when :cherry_pick then write_cherry_pick_commit
      when :revert      then write_revert_commit
      end

      exit 0
    end

    def write_merge_commit
      handle_conflicted_index

      parents = [repo.refs.read_head, pending_commit.merge_oid]
      message = compose_merge_message(MERGE_NOTES)
      write_commit(parents, message)

      pending_commit.clear(:merge)
    end

    def write_cherry_pick_commit
      handle_conflicted_index

      parents = [repo.refs.read_head]
      message = compose_merge_message(CHERRY_PICK_NOTES)

      pick_oid = pending_commit.merge_oid(:cherry_pick)
      commit   = repo.database.load(pick_oid)

      picked = Database::Commit.new(parents, write_tree.oid,
                                    commit.author, current_author,
                                    message)

      repo.database.store(picked)
      repo.refs.update_head(picked.oid)
      pending_commit.clear(:cherry_pick)
    end

    def write_revert_commit
      handle_conflicted_index

      parents = [repo.refs.read_head]
      message = compose_merge_message
      write_commit(parents, message)

      pending_commit.clear(:revert)
    end

    def compose_merge_message(notes = nil)
      edit_file(commit_message_path) do |editor|
        editor.puts(pending_commit.merge_message)
        editor.note(notes) if notes
        editor.puts("")
        editor.note(Commit::COMMIT_NOTES)
      end
    end

    def commit_message_path
      repo.git_path.join("COMMIT_EDITMSG")
    end

    def handle_conflicted_index
      return unless repo.index.conflict?

      message = "Committing is not possible because you have unmerged files"
      @stderr.puts "error: #{ message }."
      @stderr.puts CONFLICT_MESSAGE
      exit 128
    end

  end
end
