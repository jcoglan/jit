require_relative "../../pack"
require_relative "../../progress"

module Command
  module ReceiveObjects

    def recv_packed_objects(prefix = "")
      stream   = Pack::Stream.new(@conn.input, prefix)
      reader   = Pack::Reader.new(stream)
      progress = Progress.new(@stderr) unless @conn.input == STDIN

      reader.read_header

      unpacker = Pack::Unpacker.new(repo.database, reader, stream, progress)
      unpacker.process_pack
    end

  end
end
