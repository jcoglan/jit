require "pathname"

require_relative "./base"
require_relative "../revision"

module Command
  class Reset < Base

    def define_options
      @options[:mode] = :mixed

      @parser.on("--soft")  { @options[:mode] = :soft  }
      @parser.on("--mixed") { @options[:mode] = :mixed }
      @parser.on("--hard")  { @options[:mode] = :hard  }
    end

    def run
      select_commit_oid

      repo.index.load_for_update
      reset_files
      repo.index.write_updates

      if @args.empty?
        head_oid = repo.refs.update_head(@commit_oid)
        repo.refs.update_ref(Refs::ORIG_HEAD, head_oid)
      end

      exit 0
    end

    private

    def select_commit_oid
      revision = @args.fetch(0, Revision::HEAD)
      @commit_oid = Revision.new(repo, revision).resolve
      @args.shift
    rescue Revision::InvalidObject
      @commit_oid = repo.refs.read_head
    end

    def reset_files
      return if @options[:mode] == :soft
      return repo.hard_reset(@commit_oid) if @options[:mode] == :hard

      if @args.empty?
        repo.index.clear!
        reset_path(nil)
      else
        @args.each { |path| reset_path(Pathname.new(path)) }
      end
    end

    def reset_path(pathname)
      listing = repo.database.load_tree_list(@commit_oid, pathname)
      repo.index.remove(pathname) if pathname

      listing.each do |path, entry|
        repo.index.add_from_db(path, entry)
      end
    end

  end
end
