require "pathname"
require_relative "../repository"

module Command
  class Commit

    def run
      root_path = Pathname.new(Dir.getwd)
      repo = Repository.new(root_path.join(".git"))

      repo.index.load

      root = Database::Tree.build(repo.index.each_entry)
      root.traverse { |tree| repo.database.store(tree) }

      parent  = repo.refs.read_head
      name    = ENV.fetch("GIT_AUTHOR_NAME")
      email   = ENV.fetch("GIT_AUTHOR_EMAIL")
      author  = Database::Author.new(name, email, Time.now)
      message = $stdin.read

      commit = Database::Commit.new(parent, root.oid, author, message)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)

      is_root = parent.nil? ? "(root-commit) " : ""
      puts "[#{ is_root }#{ commit.oid }] #{ message.lines.first }"
      exit 0
    end

  end
end
