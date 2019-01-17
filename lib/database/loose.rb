require "strscan"
require "zlib"

require_relative "../temp_file"

class Database
  class Loose

    def initialize(pathname)
      @pathname = pathname
    end

    def has?(oid)
      File.file?(object_path(oid))
    end

    def load_info(oid)
      type, size, _ = read_object_header(oid, 128)
      Raw.new(type, size)
    rescue Errno::ENOENT
      nil
    end

    def load_raw(oid)
      type, size, scanner = read_object_header(oid)
      Raw.new(type, size, scanner.rest)
    rescue Errno::ENOENT
      nil
    end

    def prefix_match(name)
      dirname = object_path(name).dirname

      oids = Dir.entries(dirname).map do |filename|
        "#{ dirname.basename }#{ filename }"
      end

      oids.select { |oid| oid.start_with?(name) }
    rescue Errno::ENOENT
      []
    end

    def write_object(oid, content)
      path = object_path(oid)
      return if File.exist?(path)

      file = TempFile.new(path.dirname, "tmp_obj")
      file.write(Zlib::Deflate.deflate(content, Zlib::BEST_SPEED))
      file.move(path.basename)
    end

    private

    def object_path(oid)
      @pathname.join(oid[0..1], oid[2..-1])
    end

    def read_object_header(oid, read_bytes = nil)
      path    = object_path(oid)
      data    = Zlib::Inflate.new.inflate(File.read(path, read_bytes))
      scanner = StringScanner.new(data)

      type = scanner.scan_until(/ /).strip
      size = scanner.scan_until(/\0/)[0..-2].to_i

      [type, size, scanner]
    end

  end
end
