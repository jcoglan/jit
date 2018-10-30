require_relative "./pack/writer"

module Pack
  HEADER_SIZE   = 12
  HEADER_FORMAT = "a4N2"
  SIGNATURE     = "PACK"
  VERSION       = 2

  COMMIT = 1
  TREE   = 2
  BLOB   = 3
end
