require "digest/sha1"
require "set"

require_relative "./index/entry"
require_relative "./lockfile"

class Index
  HEADER_FORMAT = "a4N2"

  def initialize(pathname)
    @entries  = {}
    @keys     = SortedSet.new
    @lockfile = Lockfile.new(pathname)
  end

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    @keys.add(entry.key)
    @entries[entry.key] = entry
  end

  def each_entry
    @keys.each { |key| yield @entries[key] }
  end

  def write_updates
    return false unless @lockfile.hold_for_update

    begin_write
    header = ["DIRC", 2, @entries.size].pack(HEADER_FORMAT)
    write(header)
    each_entry { |entry| write(entry.to_s) }
    finish_write

    true
  end

  private

  def begin_write
    @digest = Digest::SHA1.new
  end

  def write(data)
    @lockfile.write(data)
    @digest.update(data)
  end

  def finish_write
    @lockfile.write(@digest.digest)
    @lockfile.commit
  end
end
