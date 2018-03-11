class Revision
  InvalidObject = Class.new(StandardError)
  HintedError   = Struct.new(:message, :hint)

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
    | ^\/
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
      rev = Revision.parse(match[1])
      rev ? Parent.new(rev) : nil
    elsif match = ANCESTOR.match(revision)
      rev = Revision.parse(match[1])
      rev ? Ancestor.new(rev, match[2].to_i) : nil
    elsif Revision.valid_ref?(revision)
      name = REF_ALIASES[revision] || revision
      Ref.new(name)
    end
  end

  def self.valid_ref?(revision)
    INVALID_NAME =~ revision ? false : true
  end

  attr_reader :errors

  def initialize(repo, expression)
    @repo   = repo
    @expr   = expression
    @query  = Revision.parse(@expr)
    @errors = []
  end

  def resolve
    oid = @query&.resolve(self)
    return oid if oid

    raise InvalidObject, "Not a valid object name: '#{ @expr }'."
  end

  def read_ref(name)
    oid = @repo.refs.read_ref(name)
    return oid if oid

    candidates = @repo.database.prefix_match(name)
    return candidates.first if candidates.size == 1

    if candidates.size > 1
      log_ambiguous_sha1(name, candidates)
    end

    nil
  end

  def commit_parent(oid)
    return nil unless oid

    commit = @repo.database.load(oid)
    commit.parent
  end

  private

  def log_ambiguous_sha1(name, candidates)
    objects = candidates.sort.map do |oid|
      object = @repo.database.load(oid)
      short  = @repo.database.short_oid(object.oid)
      info   = "  #{ short } #{ object.type }"

      if object.type == "commit"
        "#{ info } #{ object.author.short_date } - #{ object.title_line }"
      else
        info
      end
    end

    message = "short SHA1 #{ name } is ambiguous"
    hint = ["The candidates are:"] + objects
    @errors.push(HintedError.new(message, hint))
  end
end
