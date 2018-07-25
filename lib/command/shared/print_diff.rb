    def from_entry(path, entry)
      return from_nothing(path) unless entry

      blob = repo.database.load(entry.oid)
      Target.new(path, entry.oid, entry.mode.to_s(8), blob.data)
    end

    def from_nothing(path)
      Target.new(path, NULL_OID, nil, "")
    end

    def print_commit_diff(a, b, differ = nil)
      differ ||= repo.database
      diff     = differ.tree_diff(a, b)
      paths    = diff.keys.sort_by(&:to_s)

      paths.each do |path|
        old_entry, new_entry = diff[path]
        print_diff(from_entry(path, old_entry), from_entry(path, new_entry))
      end
    end
