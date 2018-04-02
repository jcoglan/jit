require "fileutils"

require_relative "./lockfile"
require_relative "./revision"

class Refs
  InvalidBranch = Class.new(StandardError)

  SymRef = Struct.new(:path)
  Ref    = Struct.new(:oid)

  HEAD   = "HEAD"
  SYMREF = /^ref: (.+)$/

  def initialize(pathname)
    @pathname   = pathname
    @refs_path  = @pathname.join("refs")
    @heads_path = @refs_path.join("heads")
  end

  def read_head
    read_symref(@pathname.join(HEAD))
  end

  def update_head(oid)
    update_ref_file(@pathname.join(HEAD), oid)
  end

  def set_head(revision, oid)
    head = @pathname.join(HEAD)
    path = @heads_path.join(revision)

    if File.file?(path)
      relative = path.relative_path_from(@pathname)
      update_ref_file(head, "ref: #{ relative }")
    else
      update_ref_file(head, oid)
    end
  end

  def read_ref(name)
    path = path_for_name(name)
    path ? read_symref(path) : nil
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

  def current_ref(source = HEAD)
    ref = read_oid_or_symref(@pathname.join(source))

    case ref
    when SymRef   then current_ref(ref.path)
    when Ref, nil then SymRef.new(source)
    end
  end

  private

  def path_for_name(name)
    prefixes = [@pathname, @refs_path, @heads_path]
    prefix   = prefixes.find { |path| File.file? path.join(name) }

    prefix ? prefix.join(name) : nil
  end

  def read_oid_or_symref(path)
    data  = File.read(path).strip
    match = SYMREF.match(data)

    match ? SymRef.new(match[1]) : Ref.new(data)
  rescue Errno::ENOENT
    nil
  end

  def read_symref(path)
    ref = read_oid_or_symref(path)

    case ref
    when SymRef then read_symref(@pathname.join(ref.path))
    when Ref    then ref.oid
    end
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
