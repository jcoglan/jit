require "fileutils"
require "pathname"

require "database"

module GraphHelper
  def self.included(suite)
    suite.before { FileUtils.mkdir_p(db_path) }
    suite.after  { FileUtils.rm_rf(db_path) }
  end

  def db_path
    Pathname.new(File.expand_path("../test-database", __FILE__))
  end

  def database
    @database ||= Database.new(db_path)
  end

  def commit(parents, message)
    @commits ||= {}
    @time    ||= Time.now

    parents = parents.map { |oid| @commits[oid] }
    author  = Database::Author.new("A. U. Thor", "author@example.com", @time)
    commit  = Database::Commit.new(parents, "0" * 40, author, author, message)

    database.store(commit)
    @commits[message] = commit.oid
  end

  def chain(names)
    names.each_cons(2) { |parent, message| commit([*parent], message) }
  end
end
