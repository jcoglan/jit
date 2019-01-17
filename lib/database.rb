require "digest/sha1"
require "forwardable"
require "pathname"
require "strscan"

require_relative "./database/author"
require_relative "./database/blob"
require_relative "./database/commit"
require_relative "./database/entry"
require_relative "./database/tree"
require_relative "./database/tree_diff"

require_relative "./database/backends"

class Database
  TYPES = {
    "blob"   => Blob,
    "tree"   => Tree,
    "commit" => Commit
  }

  Raw = Struct.new(:type, :size, :data)

  extend Forwardable
  def_delegators :@backend, :has?, :load_info, :load_raw,
                            :prefix_match, :pack_path

  def initialize(pathname)
    @objects = {}
    @backend = Backends.new(pathname)
  end

  def store(object)
    content    = serialize_object(object)
    object.oid = hash_content(content)

    @backend.write_object(object.oid, content)
  end

  def hash_object(object)
    hash_content(serialize_object(object))
  end

  def load(oid)
    @objects[oid] ||= read_object(oid)
  end

  def load_tree_entry(oid, pathname)
    commit = load(oid)
    root   = Database::Entry.new(commit.tree, Tree::TREE_MODE)

    return root unless pathname

    pathname.each_filename.reduce(root) do |entry, name|
      entry ? load(entry.oid).entries[name] : nil
    end
  end

  def load_tree_list(oid, pathname = nil)
    return {} unless oid

    entry = load_tree_entry(oid, pathname)
    list  = {}

    build_list(list, entry, pathname || Pathname.new(""))
    list
  end

  def build_list(list, entry, prefix)
    return unless entry
    return list[prefix.to_s] = entry unless entry.tree?

    load(entry.oid).each_entry do |name, item|
      build_list(list, item, prefix.join(name))
    end
  end

  def tree_entry(oid)
    Entry.new(oid, Tree::TREE_MODE)
  end

  def short_oid(oid)
    oid[0..6]
  end

  def tree_diff(a, b, prune = [])
    diff = TreeDiff.new(self, prune)
    diff.compare_oids(a, b)
    diff.changes
  end

  private

  def serialize_object(object)
    string = object.to_s.force_encoding(Encoding::ASCII_8BIT)
    "#{ object.type } #{ string.bytesize }\0#{ string }"
  end

  def hash_content(string)
    Digest::SHA1.hexdigest(string)
  end

  def read_object(oid)
    raw     = load_raw(oid)
    scanner = StringScanner.new(raw.data)

    object = TYPES[raw.type].parse(scanner)
    object.oid = oid

    object
  end
end
