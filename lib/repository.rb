require_relative "./database"
require_relative "./index"
require_relative "./refs"
require_relative "./workspace"

require_relative "./repository/migration"
require_relative "./repository/status"

class Repository
  def initialize(git_path)
    @git_path = git_path
  end

  def database
    @database ||= Database.new(@git_path.join("objects"))
  end

  def index
    @index ||= Index.new(@git_path.join("index"))
  end

  def migration(tree_diff)
    Migration.new(self, tree_diff)
  end

  def refs
    @refs ||= Refs.new(@git_path)
  end

  def status
    Status.new(self)
  end

  def workspace
    @workspace ||= Workspace.new(@git_path.dirname)
  end
end
