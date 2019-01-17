require "digest/sha1"
require "pathname"
require "strscan"
require "zlib"

require_relative "./database/author"
require_relative "./database/blob"
require_relative "./database/commit"
require_relative "./database/entry"
require_relative "./database/tree"
require_relative "./database/tree_diff"

require_relative "./temp_file"

class Database
  TYPES = {
    "blob"   => Blob,
    "tree"   => Tree,
    "commit" => Commit
  }

  Raw = Struct.new(:type, :size, :data)

  def initialize(pathname)
    @pathname = pathname
    @objects  = {}
  end

  def pack_path
    @pathname.join("pack")
  end

  def store(object)
    content    = serialize_object(object)
    object.oid = hash_content(content)

    write_object(object.oid, content)
  end

  def hash_object(object)
    hash_content(serialize_object(object))
  end

  def has?(oid)
    File.file?(object_path(oid))
  end

  def load(oid)
    @objects[oid] ||= read_object(oid)
  end

  def load_info(oid)
    type, size, _ = read_object_header(oid, 128)
    Raw.new(type, size)
  end

  def load_raw(oid)
    type, size, scanner = read_object_header(oid)
    Raw.new(type, size, scanner.rest)
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

  def prefix_match(name)
    dirname = object_path(name).dirname

    oids = Dir.entries(dirname).map do |filename|
      "#{ dirname.basename }#{ filename }"
    end

    oids.select { |oid| oid.start_with?(name) }
  rescue Errno::ENOENT
    []
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

  def object_path(oid)
    @pathname.join(oid[0..1], oid[2..-1])
  end

  def read_object_header(oid, read_bytes = nil)
    path    = object_path(oid)
    data    = Zlib::Inflate.new.inflate(File.read(path, read_bytes))
    scanner = StringScanner.new(data)

    type = scanner.scan_until(/ /).strip
    size = scanner.scan_until(/\0/)[0..-2].to_i

    [type, size, scanner]
  end

  def read_object(oid)
    type, _, scanner = read_object_header(oid)

    object = TYPES[type].parse(scanner)
    object.oid = oid

    object
  end

  def write_object(oid, content)
    path = object_path(oid)
    return if File.exist?(path)

    file = TempFile.new(path.dirname, "tmp_obj")
    file.write(Zlib::Deflate.deflate(content, Zlib::BEST_SPEED))
    file.move(path.basename)
  end
end
