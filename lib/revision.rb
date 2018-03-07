class Revision
  InvalidObject = Class.new(StandardError)

  Ref = Struct.new(:name) do
    def resolve(context)
      context.read_ref(name)
    end
  end

  Parent = Struct.new(:rev) do
    def resolve(context)
      context.commit_parent(rev.resolve(context))
    end
  end

  Ancestor = Struct.new(:rev, :n) do
    def resolve(context)
      oid = rev.resolve(context)
      n.times { oid = context.commit_parent(oid) }
      oid
    end
  end

  INVALID_NAME = /
      ^\.
    | \/\.
    | \.\.
    | \/$
    | \.lock$
    | @\{
    | [\x00-\x20*:?\[\\^~\x7f]
    /x

  PARENT   = /^(.+)\^$/
  ANCESTOR = /^(.+)~(\d+)$/

  REF_ALIASES = {
    "@" => "HEAD"
  }

  def self.parse(revision)
    if match = PARENT.match(revision)
      rev = parse(match[1])
      rev ? Parent.new(rev) : nil
    elsif match = ANCESTOR.match(revision)
      rev = parse(match[1])
      rev ? Ancestor.new(rev, match[2].to_i) : nil
    elsif valid_ref?(revision)
      name = REF_ALIASES[revision] || revision
      Ref.new(name)
    end
  end

  def self.valid_ref?(revision)
    INVALID_NAME =~ revision ? false : true
  end

  def initialize(repo, expression)
    @repo  = repo
    @expr  = expression
    @query = Revision.parse(@expr)
  end

  def resolve
    oid = @query&.resolve(self)
    return oid if oid

    raise InvalidObject, "Not a valid object name: '#{ @expr }'."
  end

  def read_ref(name)
    @repo.refs.read_ref(name)
  end

  def commit_parent(oid)
    return nil unless oid

    commit = @repo.database.load(oid)
    commit.parent
  end
end
