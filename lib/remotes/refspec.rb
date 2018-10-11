class Remotes

  REFSPEC_FORMAT = /^(\+?)([^:]+):([^:]+)$/

  Refspec = Struct.new(:source, :target, :forced) do
    def self.parse(spec)
      match = REFSPEC_FORMAT.match(spec)
      Refspec.new(match[2], match[3], match[1] == "+")
    end

    def self.expand(specs, refs)
      specs = specs.map { |spec| parse(spec) }

      specs.reduce({}) do |mappings, spec|
        mappings.merge(spec.match_refs(refs))
      end
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
