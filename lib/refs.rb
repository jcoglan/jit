require "fileutils"

require_relative "./lockfile"
require_relative "./revision"

class Refs
  InvalidBranch = Class.new(StandardError)

  HEAD = "HEAD"

  def initialize(pathname)
    @pathname   = pathname
    @refs_path  = @pathname.join("refs")
    @heads_path = @refs_path.join("heads")
  end

  def read_head
    read_ref_file(@pathname.join(HEAD))
  end

  def update_head(oid)
    update_ref_file(@pathname.join(HEAD), oid)
  end

  def read_ref(name)
    path = path_for_name(name)
    path ? read_ref_file(path) : nil
  end

  def create_branch(branch_name, start_oid)
    path = @heads_path.join(branch_name)

    unless Revision.valid_ref?(branch_name)
      raise InvalidBranch, "'#{ branch_name }' is not a valid branch name."
    end

    if File.file?(path)
      raise InvalidBranch, "A branch named '#{ branch_name }' already exists."
    end

    update_ref_file(path, start_oid)
  end

  private

  def path_for_name(name)
    prefixes = [@pathname, @refs_path, @heads_path]
    prefix   = prefixes.find { |path| File.file? path.join(name) }

    prefix ? prefix.join(name) : nil
  end

  def read_ref_file(path)
    File.read(path).strip
  rescue Errno::ENOENT
    nil
  end

  def update_ref_file(path, oid)
    lockfile = Lockfile.new(path)

    lockfile.hold_for_update
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit

  rescue Lockfile::MissingParent
    FileUtils.mkdir_p(path.dirname)
    retry
  end
end
