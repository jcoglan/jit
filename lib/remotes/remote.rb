class Remotes
  class Remote

    def initialize(config, name)
      @config = config
      @name   = name

      @config.open
    end

    def fetch_url
      @config.get(["remote", @name, "url"])
    end

    def fetch_specs
      @config.get_all(["remote", @name, "fetch"])
    end

    def push_url
      @config.get(["remote", @name, "pushurl"]) || fetch_url
    end

    def uploader
      @config.get(["remote", @name, "uploadpack"])
    end

  end
end
