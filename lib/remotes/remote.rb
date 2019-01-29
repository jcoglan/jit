require_relative "./refspec"

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

    def push_specs
      @config.get_all(["remote", @name, "push"])
    end

    def uploader
      @config.get(["remote", @name, "uploadpack"])
    end

    def receiver
      @config.get(["remote", @name, "receivepack"])
    end

    def get_upstream(branch)
      merge   = @config.get(["branch", branch, "merge"])
      targets = Refspec.expand(fetch_specs, [merge])

      targets.keys.first
    end

    def set_upstream(branch, upstream)
      ref_name = Refspec.invert(fetch_specs, upstream)
      return nil unless ref_name

      @config.open_for_update
      @config.set(["branch", branch, "remote"], @name)
      @config.set(["branch", branch, "merge"], ref_name)
      @config.save

      ref_name
    end

  end
end
