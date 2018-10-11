class Remotes

  Refspec = Struct.new(:source, :target, :forced) do
    def to_s
      spec = forced ? "+" : ""
      spec + [source, target].join(":")
    end
  end

end
