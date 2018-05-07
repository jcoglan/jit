require "pathname"

class PathFilter
  Trie = Struct.new(:matched, :children) do
    def self.from_paths(paths)
      root = Trie.node
      root.matched = true if paths.empty?

      paths.each do |path|
        trie = root
        path.each_filename { |name| trie = trie.children[name] }
        trie.matched = true
      end

      root
    end

    def self.node
      Trie.new(false, Hash.new { |hash, key| hash[key] = Trie.node })
    end
  end

  attr_reader :path

  def self.build(paths)
    PathFilter.new(Trie.from_paths(paths))
  end

  def initialize(routes = Trie.new(true), path = Pathname.new(""))
    @routes = routes
    @path   = path
  end

  def each_entry(entries)
    entries.each do |name, entry|
      yield name, entry if @routes.matched or @routes.children.has_key?(name)
    end
  end

  def join(name)
    next_routes = @routes.matched ? @routes : @routes.children[name]
    PathFilter.new(next_routes, @path.join(name))
  end
end
