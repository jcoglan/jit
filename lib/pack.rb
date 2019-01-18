require_relative "./pack/reader"
require_relative "./pack/writer"
require_relative "./pack/stream"
require_relative "./pack/indexer"
require_relative "./pack/unpacker"

module Pack
  HEADER_SIZE   = 12
  HEADER_FORMAT = "a4N2"
  SIGNATURE     = "PACK"
  VERSION       = 2

  GIT_MAX_COPY    = 0x10000
  MAX_COPY_SIZE   = 0xffffff
  MAX_INSERT_SIZE = 0x7f

  IDX_SIGNATURE  = 0xff744f63
  IDX_MAX_OFFSET = 0x80000000

  COMMIT = 1
  TREE   = 2
  BLOB   = 3

  OFS_DELTA = 6
  REF_DELTA = 7

  TYPE_CODES = {
    "commit" => COMMIT,
    "tree"   => TREE,
    "blob"   => BLOB
  }

  InvalidPack = Class.new(StandardError)

  Record = Struct.new(:type, :data) do
    attr_accessor :oid

    def to_s
      data
    end
  end

  OfsDelta = Struct.new(:base_ofs, :delta_data)
  RefDelta = Struct.new(:base_oid, :delta_data)
end
