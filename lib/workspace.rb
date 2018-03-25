require "fileutils"

class Workspace
  MissingFile  = Class.new(StandardError)
  NoPermission = Class.new(StandardError)

  IGNORE = [".", "..", ".git"]

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(path = @pathname)
    relative = path.relative_path_from(@pathname)

    if File.directory?(path)
      filenames = Dir.entries(path) - IGNORE
      filenames.flat_map { |name| list_files(path.join(name)) }
    elsif File.exist?(path)
      [relative]
    else
      raise MissingFile, "pathspec '#{ relative }' did not match any files"
    end
  end

  def list_dir(dirname)
    path    = @pathname.join(dirname || "")
    entries = Dir.entries(path) - IGNORE
    stats   = {}

    entries.each do |name|
      relative = path.join(name).relative_path_from(@pathname)
      stats[relative.to_s] = File.stat(path.join(name))
    end

    stats
  end

  def read_file(path)
    File.read(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "open('#{ path }'): Permission denied"
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  rescue Errno::ENOENT, Errno::ENOTDIR
    nil
  rescue Errno::EACCES
    raise NoPermission, "stat('#{ path }'): Permission denied"
  end

  def apply_migration(migration)
    apply_change_list(migration, :delete)
    migration.rmdirs.sort.reverse_each { |dir| remove_directory(dir) }

    migration.mkdirs.sort.each { |dir| make_directory(dir) }
    apply_change_list(migration, :update)
    apply_change_list(migration, :create)
  end

  private

  def remove_directory(dirname)
    Dir.rmdir(@pathname.join(dirname))
  rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ENOTEMPTY
  end

  def make_directory(dirname)
    path = @pathname.join(dirname)
    stat = stat_file(dirname)

    File.unlink(path) if stat&.file?
    Dir.mkdir(path) unless stat&.directory?
  end

  def apply_change_list(migration, action)
    migration.changes[action].each do |filename, entry|
      path = @pathname.join(filename)

      FileUtils.rm_rf(path)
      next if action == :delete

      flags = File::WRONLY | File::CREAT | File::EXCL
      data  = migration.blob_data(entry.oid)

      File.open(path, flags) { |file| file.write(data) }
      File.chmod(entry.mode, path)
    end
  end
end
