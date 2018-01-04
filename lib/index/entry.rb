class Index
  ENTRY_FORMAT = "N10H40nZ*"
  ENTRY_BLOCK  = 8

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
      mode  = stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
      flags = [path.bytesize, MAX_PATH_SIZE].min

      Entry.new(
        stat.ctime.to_i, stat.ctime.nsec,
        stat.mtime.to_i, stat.mtime.nsec,
        stat.dev, stat.ino, mode, stat.uid, stat.gid, stat.size,
        oid, flags, path)
    end

    def to_s
      string = to_a.pack(ENTRY_FORMAT)
      string.concat("\0") until string.bytesize % ENTRY_BLOCK == 0
      string
    end
  end
end
