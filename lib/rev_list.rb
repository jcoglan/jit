require_relative "./revision"

class RevList
  def initialize(repo, start)
    @repo  = repo
    @start = start || Revision::HEAD
  end

  def each
    oid = Revision.new(@repo, @start).resolve(Revision::COMMIT)

    while oid
      commit = @repo.database.load(oid)
      yield commit
      oid = commit.parent
    end
  end
end
