class Database
  class Blob

    attr_accessor :oid
    attr_reader :data

    def self.parse(scanner)
      Blob.new(scanner.rest)
    end

    def initialize(data)
      @data = data
    end

    def type
      "blob"
    end

    def to_s
      @data
    end

  end
end
