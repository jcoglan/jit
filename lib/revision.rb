class Revision
  Ref      = Struct.new(:name)
  Parent   = Struct.new(:rev)
  Ancestor = Struct.new(:rev, :n)

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
end
