require_relative "./lockfile"

class Refs
  def initialize(pathname)
    @pathname = pathname
  end

  def read_head
    if File.exist?(head_path)
      File.read(head_path).strip
    end
  end

  def update_head(oid)
    lockfile = Lockfile.new(head_path)

    lockfile.hold_for_update
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit
  end

  private

  def head_path
    @pathname.join("HEAD")
  end
end
