require_relative "../../pack"
require_relative "../../progress"
require_relative "../../rev_list"

module Command
  module SendObjects

    def send_packed_objects(revs)
      rev_opts = { :objects => true, :missing => true }
      rev_list = ::RevList.new(repo, revs, rev_opts)

      pack_compression = repo.config.get(["pack", "compression"]) ||
                         repo.config.get(["core", "compression"])

      writer = Pack::Writer.new(@conn.output, repo.database,
                                :compression => pack_compression,
                                :progress    => Progress.new(@stderr))

      writer.write_objects(rev_list)
    end

  end
end
