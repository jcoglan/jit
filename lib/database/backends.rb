require "forwardable"

require_relative "./loose"
require_relative "./packed"

class Database
  class Backends

    extend Forwardable
    def_delegators :@loose, :write_object

    def initialize(pathname)
      @pathname = pathname
      @loose    = Loose.new(pathname)
      @stores   = [@loose] + packed
    end

    def pack_path
      @pathname.join("pack")
    end

    def has?(oid)
      @stores.any? { |store| store.has?(oid) }
    end

    def load_info(oid)
      @stores.reduce(nil) { |info, store| info || store.load_info(oid) }
    end

    def load_raw(oid)
      @stores.reduce(nil) { |raw, store| raw || store.load_raw(oid) }
    end

    def prefix_match(name)
      oids = @stores.reduce([]) do |list, store|
        list + store.prefix_match(name)
      end

      oids.uniq
    end

    private

    def packed
      packs = Dir.entries(pack_path).grep(/\.pack$/)
              .map { |name| pack_path.join(name) }
              .sort_by { |path| File.mtime(path) }
              .reverse

      packs.map { |path| Packed.new(path) }

    rescue Errno::ENOENT
      []
    end

  end
end
