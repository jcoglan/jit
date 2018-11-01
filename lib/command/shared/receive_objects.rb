require_relative "../../pack"

module Command
  module ReceiveObjects

    def recv_packed_objects(prefix = "")
      stream = Pack::Stream.new(@conn.input, prefix)
      reader = Pack::Reader.new(stream)

      reader.read_header

      reader.count.times do
        record, _ = stream.capture { reader.read_record }
        repo.database.store(record)
      end
      stream.verify_checksum
    end

  end
end
