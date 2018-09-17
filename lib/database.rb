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

require_relative "./path_filter"

class Database
  TEMP_CHARS = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a

  TYPES = {
    "blob"   => Blob,
    "tree"   => Tree,
    "commit" => Commit
  }

  def initialize(pathname)
    @pathname = pathname
    @objects  = {}
  end

  def store(object)
    content    = serialize_object(object)
    object.oid = hash_content(content)

    write_object(object.oid, content)
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

    load(entry.oid).entries.each do |name, item|
      build_list(list, item, prefix.join(name))
    end
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

  def tree_diff(a, b, filter = PathFilter.new)
    diff = TreeDiff.new(self)
    diff.compare_oids(a, b, filter)
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

  def read_object(oid)
    data    = Zlib::Inflate.inflate(File.read(object_path(oid)))
    scanner = StringScanner.new(data)

    type  = scanner.scan_until(/ /).strip
    _size = scanner.scan_until(/\0/)[0..-2]

    object = TYPES[type].parse(scanner)
    object.oid = oid

    object
  end

  def write_object(oid, content)
    path = object_path(oid)
    return if File.exist?(path)

    dirname   = path.dirname
    temp_path = dirname.join(generate_temp_name)

    begin
      flags = File::RDWR | File::CREAT | File::EXCL
      file  = File.open(temp_path, flags)
    rescue Errno::ENOENT
      Dir.mkdir(dirname)
      file = File.open(temp_path, flags)
    end

    compressed = Zlib::Deflate.deflate(content, Zlib::BEST_SPEED)
    file.write(compressed)
    file.close

    File.rename(temp_path, path)
  end

  def generate_temp_name
    "tmp_obj_#{ (1..6).map { TEMP_CHARS.sample }.join("") }"
  end
end
