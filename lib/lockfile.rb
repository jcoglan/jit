class Lockfile
  MissingParent = Class.new(StandardError)
  NoPermission  = Class.new(StandardError)
  StaleLock     = Class.new(StandardError)

  def initialize(path)
    @file_path = path
    @lock_path = path.dirname.join("#{ path.basename }.lock")
  end

  def hold_for_update
    unless @lock
      flags = File::RDWR | File::CREAT | File::EXCL
      @lock = File.open(@lock_path, flags)
    end
    true
  rescue Errno::EEXIST
    false
  rescue Errno::ENOENT => error
    raise MissingParent, error.message
  rescue Errno::EACCES => error
    raise NoPermission, error.message
  end

  def write(string)
    raise_on_stale_lock
    @lock.write(string)
  end

  def commit
    raise_on_stale_lock

    @lock.close
    File.rename(@lock_path, @file_path)
    @lock = nil
  end

  def rollback
    raise_on_stale_lock

    @lock.close
    File.unlink(@lock_path)
    @lock = nil
  end

  private

  def raise_on_stale_lock
    unless @lock
      raise StaleLock, "Not holding lock on file: #{ @lock_path }"
    end
  end
end
