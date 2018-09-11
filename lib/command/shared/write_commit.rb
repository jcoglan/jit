module Command
  module WriteCommit

    CONFLICT_MESSAGE = <<~MSG
      hint: Fix them up in the work tree, and then use 'jit add/rm <file>'
      hint: as appropriate to mark resolution and make a commit.
      fatal: Exiting because of an unresolved conflict.
    MSG

    def write_commit(parents, message)
      tree   = write_tree
      name   = @env.fetch("GIT_AUTHOR_NAME")
      email  = @env.fetch("GIT_AUTHOR_EMAIL")
      author = Database::Author.new(name, email, Time.now)

      commit = Database::Commit.new(parents, tree.oid, author, message)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)

      commit
    end

    def write_tree
      root = Database::Tree.build(repo.index.each_entry)
      root.traverse { |tree| repo.database.store(tree) }
      root
    end

    def pending_commit
      @pending_commit ||= repo.pending_commit
    end

    def resume_merge
      handle_conflicted_index

      parents = [repo.refs.read_head, pending_commit.merge_oid]
      write_commit(parents, pending_commit.merge_message)

      pending_commit.clear
      exit 0
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
