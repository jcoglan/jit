require_relative "../../pack"
require_relative "../../progress"

module Command
  module ReceiveObjects

    UNPACK_LIMIT = 100

    def recv_packed_objects(unpack_limit = nil, prefix = "")
      stream   = Pack::Stream.new(@conn.input, prefix)
      reader   = Pack::Reader.new(stream)
      progress = Progress.new(@stderr) unless @conn.input == STDIN

      reader.read_header

      factory   = select_processor_class(reader, unpack_limit)
      processor = factory.new(repo.database, reader, stream, progress)

      processor.process_pack
    end

    def select_processor_class(reader, unpack_limit)
      unpack_limit ||= transfer_unpack_limit

      if unpack_limit and reader.count > unpack_limit
        Pack::Indexer
      else
        Pack::Unpacker
      end
    end

    def transfer_unpack_limit
      repo.config.get(["transfer", "unpackLimit"]) || UNPACK_LIMIT
    end

  end
end
