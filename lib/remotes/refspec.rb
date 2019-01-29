require "pathname"

require_relative "../refs"
require_relative "../revision"

class Remotes

  REFSPEC_FORMAT = /^(\+?)([^:]*)(:([^:]*))?$/

  Refspec = Struct.new(:source, :target, :forced) do
    def self.parse(spec)
      match  = REFSPEC_FORMAT.match(spec)
      source = canonical(match[2])
      target = canonical(match[4]) || source

      Refspec.new(source, target, match[1] == "+")
    end

    def self.canonical(name)
      return nil if name.to_s == ""
      return name unless Revision.valid_ref?(name)

      first  = Pathname.new(name).each_filename.first
      dirs   = [Refs::REFS_DIR, Refs::HEADS_DIR, Refs::REMOTES_DIR]
      prefix = dirs.find { |dir| first == dir.basename.to_s }

      (prefix&.dirname || Refs::HEADS_DIR).join(name).to_s
    end

    def self.expand(specs, refs)
      specs = specs.map { |spec| parse(spec) }

      specs.reduce({}) do |mappings, spec|
        mappings.merge(spec.match_refs(refs))
      end
    end

    def self.invert(specs, ref)
      specs = specs.map { |spec| parse(spec) }

      map = specs.reduce({}) do |mappings, spec|
        spec.source, spec.target = spec.target, spec.source
        mappings.merge(spec.match_refs([ref]))
      end

      map.keys.first
    end

    def match_refs(refs)
      return { target => [source, forced] } unless source.to_s.include?("*")

      pattern  = /^#{ source.sub("*", "(.*)") }$/
      mappings = {}

      refs.each do |ref|
        next unless match = pattern.match(ref)
        dst = match[1] ? target.sub("*", match[1]) : target
        mappings[dst] = [ref, forced]
      end

      mappings
    end

    def to_s
      spec = forced ? "+" : ""
      spec + [source, target].join(":")
    end
  end

end
