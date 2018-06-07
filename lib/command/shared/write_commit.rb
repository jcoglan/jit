module Command
  module WriteCommit

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

  end
end
