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
    flags = File::WRONLY | File::CREAT
    File.open(head_path, flags) { |file| file.puts(oid) }
  end

  private

  def head_path
    @pathname.join("HEAD")
  end
end
