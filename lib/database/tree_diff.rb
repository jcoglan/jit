require "pathname"

class Database
  class TreeDiff

    attr_reader :changes

    def initialize(database, prune = [])
      @database = database
      @changes  = {}

      build_routing_table(prune)
    end

    def compare_oids(a, b, prefix = Pathname.new(""))
      return if a == b

      a_entries = a ? oid_to_tree(a).entries : {}
      b_entries = b ? oid_to_tree(b).entries : {}

      detect_deletions(a_entries, b_entries, prefix)
      detect_additions(a_entries, b_entries, prefix)
    end

    private

    def build_routing_table(prune)
      @routes = {}

      prune.each do |path|
        table = @routes
        path.each_filename { |name| table = table[name] ||= {} }
      end
    end

    def routes_for_prefix(prefix)
      prefix.each_filename.reduce(@routes) { |table, name| table[name] || {} }
    end

    def oid_to_tree(oid)
      object = @database.load(oid)

      case object
      when Commit then @database.load(object.tree)
      when Tree   then object
      end
    end

    def detect_deletions(a, b, prefix)
      routes = routes_for_prefix(prefix)

      a.each do |name, entry|
        next unless routes.empty? or routes.has_key?(name)

        path  = prefix.join(name)
        other = b[name]

        next if entry == other

        tree_a, tree_b = [entry, other].map { |e| e&.tree? ? e.oid : nil }
        compare_oids(tree_a, tree_b, path)

        blobs = [entry, other].map { |e| e&.tree? ? nil : e }
        @changes[path] = blobs if blobs.any?
      end
    end

    def detect_additions(a, b, prefix)
      routes = routes_for_prefix(prefix)

      b.each do |name, entry|
        next unless routes.empty? or routes.has_key?(name)

        path  = prefix.join(name)
        other = a[name]

        next if other

        if entry.tree?
          compare_oids(nil, entry.oid, path)
        else
          @changes[path] = [nil, entry]
        end
      end
    end

  end
end
