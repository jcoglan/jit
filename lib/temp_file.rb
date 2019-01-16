class TempFile
  TEMP_CHARS = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a

  def initialize(dirname, prefix)
    @dirname = dirname
    @path    = @dirname.join(generate_temp_name(prefix))
    @file    = nil
  end

  def write(data)
    open_file unless @file
    @file.write(data)
  end

  def move(name)
    @file.close
    File.rename(@path, @dirname.join(name))
  end

  private

  def generate_temp_name(prefix)
    id = (1..6).map { TEMP_CHARS.sample }.join("")
    "#{ prefix }_#{ id }"
  end

  def open_file
    flags = File::RDWR | File::CREAT | File::EXCL
    @file = File.open(@path, flags)
  rescue Errno::ENOENT
    Dir.mkdir(@dirname)
    retry
  end
end
