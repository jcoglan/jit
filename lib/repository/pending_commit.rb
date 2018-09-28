class Repository
  class PendingCommit

    Error = Class.new(StandardError)

    HEAD_FILES = {
      :merge       => "MERGE_HEAD",
      :cherry_pick => "CHERRY_PICK_HEAD",
      :revert      => "REVERT_HEAD"
    }

    attr_reader :message_path

    def initialize(pathname)
      @pathname     = pathname
      @message_path = pathname.join("MERGE_MSG")
    end

    def start(oid, type = :merge)
      path  = @pathname.join(HEAD_FILES.fetch(type))
      flags = File::WRONLY | File::CREAT | File::EXCL
      File.open(path, flags) { |f| f.puts(oid) }
    end

    def in_progress?
      merge_type != nil
    end

    def merge_type
      HEAD_FILES.each do |type, name|
        path = @pathname.join(name)
        return type if File.file?(path)
      end

      nil
    end

    def merge_oid(type = :merge)
      head_path = @pathname.join(HEAD_FILES.fetch(type))
      File.read(head_path).strip
    rescue Errno::ENOENT
      name = head_path.basename
      raise Error, "There is no merge in progress (#{ name } missing)."
    end

    def merge_message
      File.read(@message_path)
    end

    def clear(type = :merge)
      head_path = @pathname.join(HEAD_FILES.fetch(type))
      File.unlink(head_path)
      File.unlink(@message_path)
    rescue Errno::ENOENT
      name = head_path.basename
      raise Error, "There is no merge to abort (#{ name } missing)."
    end

  end
end
