require "digest/sha1"

require_relative "./index/entry"
require_relative "./lockfile"

class Index
  HEADER_FORMAT = "a4N2"

  def initialize(pathname)
    @entries  = {}
    @lockfile = Lockfile.new(pathname)
  end

  def write_updates
    return false unless @lockfile.hold_for_update

    begin_write
    header = ["DIRC", 2, @entries.size].pack(HEADER_FORMAT)
    write(header)
    @entries.each { |key, entry| write(entry.to_s) }
    finish_write

    true
  end

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    @entries[pathname.to_s] = entry
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
