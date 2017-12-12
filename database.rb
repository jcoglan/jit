require "digest/sha1"
require "zlib"

require_relative "./blob"
require_relative "./commit"
require_relative "./tree"

class Database
  TEMP_CHARS = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a

  def initialize(pathname)
    @pathname = pathname
  end

  def store(object)
    string  = object.to_s.force_encoding(Encoding::ASCII_8BIT)
    content = "#{ object.type } #{ string.bytesize }\0#{ string }"

    object.oid = Digest::SHA1.hexdigest(content)
    write_object(object.oid, content)
  end

  private

  def write_object(oid, content)
    object_path = @pathname.join(oid[0..1], oid[2..-1])
    return if File.exist?(object_path)

    dirname   = object_path.dirname
    temp_path = dirname.join(generate_temp_name)

    begin
      flags = File::RDWR | File::CREAT | File::EXCL
      file  = File.open(temp_path, flags)
    rescue Errno::ENOENT
      Dir.mkdir(dirname)
      file = File.open(temp_path, flags)
    end

    compressed = Zlib::Deflate.deflate(content, Zlib::BEST_SPEED)
    file.write(compressed)
    file.close

    File.rename(temp_path, object_path)
  end

  def generate_temp_name
    "tmp_obj_#{ (1..6).map { TEMP_CHARS.sample }.join("") }"
  end
end
