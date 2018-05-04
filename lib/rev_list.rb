require "set"
require_relative "./revision"

class RevList
  def initialize(repo, revs)
    @repo    = repo
    @commits = {}
    @flags   = Hash.new { |hash, oid| hash[oid] = Set.new }
    @queue   = []

    revs.each { |rev| handle_revision(rev) }
    handle_revision(Revision::HEAD) if @queue.empty?
  end

  def each
    traverse_commits { |commit| yield commit }
  end

  private

  def handle_revision(rev)
    oid = Revision.new(@repo, rev).resolve(Revision::COMMIT)

    commit = load_commit(oid)
    enqueue_commit(commit)
  end

  def enqueue_commit(commit)
    return unless mark(commit.oid, :seen)

    index = @queue.find_index { |c| c.date < commit.date }
    @queue.insert(index || @queue.size, commit)
  end

  def add_parents(commit)
    return unless mark(commit.oid, :added)

    parent = load_commit(commit.parent)
    enqueue_commit(parent) if parent
  end

  def traverse_commits
    until @queue.empty?
      commit = @queue.shift
      add_parents(commit)
      yield commit
    end
  end

  def load_commit(oid)
    return nil unless oid
    @commits[oid] ||= @repo.database.load(oid)
  end

  def mark(oid, flag)
    @flags[oid].add?(flag)
  end
end
