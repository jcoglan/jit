require "pathname"

require_relative "./base"
require_relative "../revision"

module Command
  class Reset < Base

    def run
      select_commit_oid

      repo.index.load_for_update
      @args.each { |path| reset_path(Pathname.new(path)) }
      repo.index.write_updates

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

    def reset_path(pathname)
      listing = repo.database.load_tree_list(@commit_oid, pathname)
      repo.index.remove(pathname)

      listing.each do |path, entry|
        repo.index.add_from_db(path, entry)
      end
    end

  end
end
