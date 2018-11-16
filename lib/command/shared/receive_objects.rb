require_relative "../../pack"
require_relative "../../progress"

module Command
  module ReceiveObjects

    def recv_packed_objects(prefix = "")
      stream   = Pack::Stream.new(@conn.input, prefix)
      reader   = Pack::Reader.new(stream)
      progress = Progress.new(@stderr) unless @conn.input == STDIN

      reader.read_header
      progress&.start("Unpacking objects", reader.count)

      reader.count.times do
        record, _ = stream.capture { reader.read_record }
        repo.database.store(record)
        progress&.tick(stream.offset)
      end
      progress&.stop

      stream.verify_checksum
    end

  end
end
