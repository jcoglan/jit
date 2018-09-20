require "set"

require_relative "./index/checksum"
require_relative "./index/entry"
require_relative "./lockfile"

class Index
  Invalid = Class.new(StandardError)

  HEADER_SIZE   = 12
  HEADER_FORMAT = "a4N2"
  SIGNATURE     = "DIRC"
  VERSION       = 2

  def initialize(pathname)
    @pathname = pathname
    @lockfile = Lockfile.new(pathname)
    clear
  end

  def clear!
    clear
    @changed = true
  end

  def load_for_update
    @lockfile.hold_for_update
    load
  end

  def load
    clear
    file = open_index_file

    if file
      reader = Checksum.new(file)
      count = read_header(reader)
      read_entries(reader, count)
      reader.verify_checksum
    end
  ensure
    file&.close
  end

  def write_updates
    return @lockfile.rollback unless @changed

    writer = Checksum.new(@lockfile)

    header = [SIGNATURE, VERSION, @entries.size].pack(HEADER_FORMAT)
    writer.write(header)
    each_entry { |entry| writer.write(entry.to_s) }

    writer.write_checksum
    @lockfile.commit

    @changed = false
  end

  def release_lock
    @lockfile.rollback
  end

  def add(pathname, oid, stat)
    (1..3).each { |stage| remove_entry_with_stage(pathname, stage) }

    entry = Entry.create(pathname, oid, stat)
    discard_conflicts(entry)
    store_entry(entry)
    @changed = true
  end

  def add_from_db(pathname, item)
    store_entry(Entry.create_from_db(pathname, item, 0))
    @changed = true
  end

  def add_conflict_set(pathname, items)
    remove_entry_with_stage(pathname, 0)

    items.each_with_index do |item, n|
      next unless item
      entry = Entry.create_from_db(pathname, item, n + 1)
      store_entry(entry)
    end
    @changed = true
  end

  def update_entry_stat(entry, stat)
    entry.update_stat(stat)
    @changed = true
  end

  def remove(pathname)
    remove_entry(pathname)
    remove_children(pathname.to_s)
    @changed = true
  end

  def each_entry
    if block_given?
      @keys.each { |key| yield @entries[key] }
    else
      enum_for(:each_entry)
    end
  end

  def conflict?
    @entries.any? { |key, entry| entry.stage > 0 }
  end

  def conflict_paths
    paths = Set.new
    each_entry { |entry| paths.add(entry.path) unless entry.stage == 0 }
    paths
  end

  def entry_for_path(path, stage = 0)
    @entries[[path.to_s, stage]]
  end

  def child_paths(path)
    @parents[path.to_s].to_a
  end

  def tracked_file?(path)
    (0..3).any? { |stage| @entries.has_key?([path.to_s, stage]) }
  end

  def tracked_directory?(path)
    @parents.has_key?(path.to_s)
  end

  def tracked?(path)
    tracked_file?(path) or tracked_directory?(path)
  end

  private

  def clear
    @entries = {}
    @keys    = SortedSet.new
    @parents = Hash.new { |hash, key| hash[key] = Set.new }
    @changed = false
  end

  def discard_conflicts(entry)
    entry.parent_directories.each { |parent| remove_entry(parent) }
    remove_children(entry.path)
  end

  def remove_entry(pathname)
    (0..3).each { |stage| remove_entry_with_stage(pathname, stage) }
  end

  def remove_entry_with_stage(pathname, stage)
    entry = @entries[[pathname.to_s, stage]]
    return unless entry

    @keys.delete(entry.key)
    @entries.delete(entry.key)

    entry.parent_directories.each do |dirname|
      dir = dirname.to_s
      @parents[dir].delete(entry.path)
      @parents.delete(dir) if @parents[dir].empty?
    end
  end

  def remove_children(path)
    return unless @parents.has_key?(path)

    children = @parents[path].clone
    children.each { |child| remove_entry(child) }
  end

  def store_entry(entry)
    @keys.add(entry.key)
    @entries[entry.key] = entry

    entry.parent_directories.each do |dirname|
      @parents[dirname.to_s].add(entry.path)
    end
  end

  def open_index_file
    File.open(@pathname, File::RDONLY)
  rescue Errno::ENOENT
    nil
  end

  def read_header(reader)
    data = reader.read(HEADER_SIZE)
    signature, version, count = data.unpack(HEADER_FORMAT)

    unless signature == SIGNATURE
      raise Invalid, "Signature: expected '#{ SIGNATURE }' but found '#{ signature }'"
    end
    unless version == VERSION
      raise Invalid, "Version: expected '#{ VERSION }' but found '#{ version }'"
    end

    count
  end

  def read_entries(reader, count)
    count.times do
      entry = reader.read(ENTRY_MIN_SIZE)

      until entry.byteslice(-1) == "\0"
        entry.concat(reader.read(ENTRY_BLOCK))
      end

      store_entry(Entry.parse(entry))
    end
  end
end
