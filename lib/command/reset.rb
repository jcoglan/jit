require "pathname"
require_relative "./base"

module Command
  class Reset < Base

    def run
      @head_oid = repo.refs.read_head

      repo.index.load_for_update
      @args.each { |path| reset_path(Pathname.new(path)) }
      repo.index.write_updates

      exit 0
    end

    private

    def reset_path(pathname)
      listing = repo.database.load_tree_list(@head_oid, pathname)
      repo.index.remove(pathname)

      listing.each do |path, entry|
        repo.index.add_from_db(path, entry)
      end
    end

  end
end
