require_relative "./expander"

module Pack
  class Unpacker

    def initialize(database, reader, stream, progress)
      @database = database
      @reader   = reader
      @stream   = stream
      @progress = progress
    end

    def process_pack
      @progress&.start("Unpacking objects", @reader.count)

      @reader.count.times do
        process_record
        @progress&.tick(@stream.offset)
      end
      @progress&.stop

      @stream.verify_checksum
    end

    private

    def process_record
      record, _ = @stream.capture { @reader.read_record }

      record = resolve(record)
      @database.store(record)
    end

    def resolve(record)
      case record
      when Record   then record
      when RefDelta then resolve_ref_delta(record)
      end
    end

    def resolve_ref_delta(delta)
      resolve_delta(delta.base_oid, delta.delta_data)
    end

    def resolve_delta(oid, delta_data)
      base = @database.load_raw(oid)
      data = Expander.expand(base.data, delta_data)

      Record.new(base.type, data)
    end

  end
end
