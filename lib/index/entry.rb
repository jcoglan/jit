require "pathname"

class Index
  ENTRY_FORMAT   = "N10H40nZ*"
  ENTRY_BLOCK    = 8
  ENTRY_MIN_SIZE = 64

  REGULAR_MODE    = 0100644
  EXECUTABLE_MODE = 0100755
  MAX_PATH_SIZE   = 0xfff

  entry_fields = [
    :ctime, :ctime_nsec,
    :mtime, :mtime_nsec,
    :dev, :ino, :mode, :uid, :gid, :size,
    :oid, :flags, :path
  ]

  Entry = Struct.new(*entry_fields) do
    def self.create(pathname, oid, stat)
      path  = pathname.to_s
      mode  = Entry.mode_for_stat(stat)
      flags = [path.bytesize, MAX_PATH_SIZE].min

      Entry.new(
        stat.ctime.to_i, stat.ctime.nsec,
        stat.mtime.to_i, stat.mtime.nsec,
        stat.dev, stat.ino, mode, stat.uid, stat.gid, stat.size,
        oid, flags, path)
    end

    def self.create_from_db(pathname, item, n)
      path  = pathname.to_s
      flags = (n << 12) | [path.bytesize, MAX_PATH_SIZE].min

      Entry.new(0, 0, 0, 0, 0, 0, item.mode, 0, 0, 0, item.oid, flags, path)
    end

    def self.mode_for_stat(stat)
      stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
    end

    def self.parse(data)
      Entry.new(*data.unpack(ENTRY_FORMAT))
    end

    def key
      [path, stage]
    end

    def stage
      (flags >> 12) & 0x3
    end

    def parent_directories
      Pathname.new(path).descend.to_a[0..-2]
    end

    def basename
      Pathname.new(path).basename
    end

    def update_stat(stat)
      self.ctime      = stat.ctime.to_i
      self.ctime_nsec = stat.ctime.nsec
      self.mtime      = stat.mtime.to_i
      self.mtime_nsec = stat.mtime.nsec
      self.dev        = stat.dev
      self.ino        = stat.ino
      self.mode       = Entry.mode_for_stat(stat)
      self.uid        = stat.uid
      self.gid        = stat.gid
      self.size       = stat.size
    end

    def stat_match?(stat)
      mode == Entry.mode_for_stat(stat) and (size == 0 or size == stat.size)
    end

    def times_match?(stat)
      ctime == stat.ctime.to_i and ctime_nsec == stat.ctime.nsec and
      mtime == stat.mtime.to_i and mtime_nsec == stat.mtime.nsec
    end

    def to_s
      string = to_a.pack(ENTRY_FORMAT)
      string.concat("\0") until string.bytesize % ENTRY_BLOCK == 0
      string
    end
  end
end
