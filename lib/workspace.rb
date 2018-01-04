class Workspace
  IGNORE = [".", "..", ".git"]

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(path = @pathname)
    if File.directory?(path)
      filenames = Dir.entries(path) - IGNORE

      filenames.flat_map do |name|
        list_files(path.join(name))
      end
    else
      [path.relative_path_from(@pathname)]
    end
  end

  def read_file(path)
    File.read(@pathname.join(path))
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  end
end
