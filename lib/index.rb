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

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    discard_conflicts(entry)
    store_entry(entry)
    @changed = true
  end

  def each_entry
    if block_given?
      @keys.each { |key| yield @entries[key] }
    else
      enum_for(:each_entry)
    end
  end

  def load_for_update
    if @lockfile.hold_for_update
      load
      true
    else
      false
    end
  end

  def load
    clear

    open_index_file do |file|
      reader = Checksum.new(file)
      count = read_header(reader)
      read_entries(reader, count)
      reader.verify_checksum
    end
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

  private

  def clear
    @entries = {}
    @keys    = SortedSet.new
    @changed = false
  end

  def discard_conflicts(entry)
    entry.parent_directories.each do |dirname|
      @keys.delete(dirname.to_s)
      @entries.delete(dirname.to_s)
    end
  end

  def store_entry(entry)
    @keys.add(entry.key)
    @entries[entry.key] = entry
  end

  def open_index_file(&block)
    File.open(@pathname, File::RDONLY, &block)
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
    count.times do |n|
      entry = reader.read(ENTRY_MIN_SIZE)

      until entry.byteslice(-1) == "\0"
        entry << reader.read(ENTRY_BLOCK)
      end

      store_entry(Entry.parse(entry))
    end
  end
end
