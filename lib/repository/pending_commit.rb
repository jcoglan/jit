class Repository
  class PendingCommit

    Error = Class.new(StandardError)

    def initialize(pathname)
      @head_path    = pathname.join("MERGE_HEAD")
      @message_path = pathname.join("MERGE_MSG")
    end

    def start(oid, message)
      flags = File::WRONLY | File::CREAT | File::EXCL
      File.open(@head_path, flags) { |f| f.puts(oid) }
      File.open(@message_path, flags) { |f| f.write(message) }
    end

    def in_progress?
      File.file?(@head_path)
    end

    def merge_oid
      File.read(@head_path).strip
    rescue Errno::ENOENT
      name = @head_path.basename
      raise Error, "There is no merge in progress (#{ name } missing)."
    end

    def merge_message
      File.read(@message_path)
    end

    def clear
      File.unlink(@head_path)
      File.unlink(@message_path)
    end

  end
end
