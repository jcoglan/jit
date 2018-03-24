require "pathname"

class Database
  class TreeDiff

    attr_reader :changes

    def initialize(database)
      @database = database
      @changes  = {}
    end

    def compare_oids(a, b, prefix = Pathname.new(""))
      return if a == b

      a_entries = a ? oid_to_tree(a).entries : {}
      b_entries = b ? oid_to_tree(b).entries : {}

      detect_deletions(a_entries, b_entries, prefix)
      detect_additions(a_entries, b_entries, prefix)
    end

    private

    def oid_to_tree(oid)
      object = @database.load(oid)

      case object
      when Commit then @database.load(object.tree)
      when Tree   then object
      end
    end

    def detect_deletions(a, b, prefix)
      a.each do |name, entry|
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
      b.each do |name, entry|
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
