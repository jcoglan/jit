require_relative "../../pack"
require_relative "../../rev_list"

module Command
  module SendObjects

    def send_packed_objects(revs)
      rev_opts = { :objects => true, :missing => true }
      rev_list = ::RevList.new(repo, revs, rev_opts)

      pack_compression = repo.config.get(["pack", "compression"]) ||
                         repo.config.get(["core", "compression"])

      write_opts = { :compression => pack_compression }
      writer     = Pack::Writer.new(@conn.output, repo.database, write_opts)

      writer.write_objects(rev_list)
    end

  end
end
