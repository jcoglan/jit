require "pathname"
require_relative "./base"

module Command
  class Commit < Base

    def run
      repo.index.load

      root = Database::Tree.build(repo.index.each_entry)
      root.traverse { |tree| repo.database.store(tree) }

      parent  = repo.refs.read_head
      name    = @env.fetch("GIT_AUTHOR_NAME")
      email   = @env.fetch("GIT_AUTHOR_EMAIL")
      author  = Database::Author.new(name, email, Time.now)
      message = @stdin.read

      commit = Database::Commit.new(parent, root.oid, author, message)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)

      is_root = parent.nil? ? "(root-commit) " : ""
      puts "[#{ is_root }#{ commit.oid }] #{ message.lines.first }"
      exit 0
    end

  end
end
