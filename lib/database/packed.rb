require "forwardable"

require_relative "../pack/expander"
require_relative "../pack/index"
require_relative "../pack/reader"

class Database
  class Packed

    extend Forwardable
    def_delegators :@index, :prefix_match

    def initialize(pathname)
      @pack_file = File.open(pathname, File::RDONLY)
      @reader    = Pack::Reader.new(@pack_file)

      @index_file = File.open(pathname.sub_ext(".idx"), File::RDONLY)
      @index      = Pack::Index.new(@index_file)
    end

    def has?(oid)
      @index.oid_offset(oid) != nil
    end

    def load_info(oid)
      offset = @index.oid_offset(oid)
      offset ? load_info_at(offset) : nil
    end

    def load_raw(oid)
      offset = @index.oid_offset(oid)
      offset ? load_raw_at(offset) : nil
    end

    private

    def load_info_at(offset)
      @pack_file.seek(offset)
      record = @reader.read_info

      case record
      when Pack::Record
        Raw.new(record.type, record.data)
      when Pack::RefDelta
        base = load_info(record.base_oid)
        Raw.new(base.type, record.delta_data)
      end
    end

    def load_raw_at(offset)
      @pack_file.seek(offset)
      record = @reader.read_record

      case record
      when Pack::Record
        record
      when Pack::RefDelta
        base = load_raw(record.base_oid)
        expand_delta(base, record)
      end
    end

    def expand_delta(base, record)
      data = Pack::Expander.expand(base.data, record.delta_data)
      Pack::Record.new(base.type, data)
    end

  end
end
