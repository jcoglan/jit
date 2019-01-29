require_relative "./refs"
require_relative "./remotes/refspec"
require_relative "./remotes/remote"

class Remotes
  DEFAULT_REMOTE = "origin"

  InvalidBranch = Class.new(StandardError)
  InvalidRemote = Class.new(StandardError)

  def initialize(config)
    @config = config
  end

  def add(name, url, branches = [])
    branches = ["*"] if branches.empty?
    @config.open_for_update

    if @config.get(["remote", name, "url"])
      @config.save
      raise InvalidRemote, "remote #{ name } already exists."
    end

    @config.set(["remote", name, "url"], url)

    branches.each do |branch|
      source  = Refs::HEADS_DIR.join(branch)
      target  = Refs::REMOTES_DIR.join(name, branch)
      refspec = Refspec.new(source, target, true)

      @config.add(["remote", name, "fetch"], refspec.to_s)
    end

    @config.save
  end

  def remove(name)
    @config.open_for_update

    unless @config.remove_section(["remote", name])
      raise InvalidRemote, "No such remote: #{ name }"
    end
  ensure
    @config.save
  end

  def list_remotes
    @config.open
    @config.subsections("remote")
  end

  def get(name)
    @config.open
    return nil unless @config.section?(["remote", name])

    Remote.new(@config, name)
  end

  def get_upstream(branch)
    @config.open
    name = @config.get(["branch", branch, "remote"])
    get(name)&.get_upstream(branch)
  end

  def set_upstream(branch, upstream)
    list_remotes.each do |name|
      ref = get(name).set_upstream(branch, upstream)
      return [name, ref] if ref
    end

    raise InvalidBranch,
      "Cannot setup tracking information; " +
      "starting point '#{ upstream }' is not a branch"
  end

  def unset_upstream(branch)
    @config.open_for_update
    @config.unset(["branch", branch, "remote"])
    @config.unset(["branch", branch, "merge"])
    @config.save
  end
end
