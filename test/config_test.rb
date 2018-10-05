require "minitest/autorun"
require "fileutils"
require "pathname"

require "config"

describe Config do
  def open_config
    Config.new(Pathname.new(@path)).tap(&:open)
  end

  before do
    @path   = File.expand_path("../test-config", __FILE__)
    @config = open_config
  end

  after do
    FileUtils.rm_rf(@path)
  end

  describe "in memory" do
    it "returns nil for an unknown key" do
      assert_nil @config.get(%w[core editor])
    end

    it "returns the value for a known key" do
      @config.set(%w[core editor], "ed")
      assert_equal "ed", @config.get(%w[core editor])
    end

    it "returns the value for a known key" do
      @config.set(%w[core editor], "ed")
      assert_equal "ed", @config.get(%w[core editor])
    end

    it "treats section names as case-insensitive" do
      @config.set(%w[core editor], "ed")
      assert_equal "ed", @config.get(%w[Core editor])
    end

    it "treats variable names as case-insensitive" do
      @config.set(%w[core editor], "ed")
      assert_equal "ed", @config.get(%w[core Editor])
    end

    it "retrieves values from subsections" do
      @config.set(%w[branch master remote], "origin")
      assert_equal "origin", @config.get(%w[branch master remote])
    end

    it "treats subsection names as case-sensitive" do
      @config.set(%w[branch master remote], "origin")
      assert_nil @config.get(%w[branch Master remote])
    end

    it "adds multiple values for a key" do
      key = %w[remote origin fetch]

      @config.add(key, "master")
      @config.add(key, "topic")

      assert_equal "topic", @config.get(key)
      assert_equal ["master", "topic"], @config.get_all(key)
    end

    it "refuses to set a value for a multi-valued key" do
      key = %w[remote origin fetch]

      @config.add(key, "master")
      @config.add(key, "topic")

      assert_raises(Config::Conflict) { @config.set(key, "new-value") }
    end

    it "replaces all the values for a multi-valued key" do
      key = %w[remote origin fetch]

      @config.add(key, "master")
      @config.add(key, "topic")
      @config.replace_all(key, "new-value")

      assert_equal ["new-value"], @config.get_all(key)
    end
  end

  describe "file storage" do
    def assert_file(contents)
      assert_equal contents, File.read(@path)
    end

    before do
      @config.open_for_update
    end

    it "writes a single setting" do
      @config.set(%w[core editor], "ed")
      @config.save

      assert_file <<~CONFIG
        [core]
        \teditor = ed
      CONFIG
    end

    it "writes multiple settings" do
      @config.set(%w[core editor], "ed")
      @config.set(%w[user name], "A. U. Thor")
      @config.set(%w[Core bare], true)
      @config.save

      assert_file <<~CONFIG
        [core]
        \teditor = ed
        \tbare = true
        [user]
        \tname = A. U. Thor
      CONFIG
    end

    it "writes multiple subsections" do
      @config.set(%w[branch master remote], "origin")
      @config.set(%w[branch Master remote], "another")
      @config.save

      assert_file <<~CONFIG
        [branch "master"]
        \tremote = origin
        [branch "Master"]
        \tremote = another
      CONFIG
    end

    it "overwrites a variable with a matching name" do
      @config.set(%w[merge conflictstyle], "diff3")
      @config.set(%w[merge ConflictStyle], "none")
      @config.save

      assert_file <<~CONFIG
        [merge]
        \tConflictStyle = none
      CONFIG
    end

    it "retrieves persisted settings" do
      @config.set(%w[core editor], "ed")
      @config.save

      assert_equal "ed", open_config.get(%w[core editor])
    end

    it "retrieves variables from subsections" do
      @config.set(%w[branch master remote], "origin")
      @config.set(%w[branch Master remote], "another")
      @config.save

      assert_equal "origin", open_config.get(%w[branch master remote])
      assert_equal "another", open_config.get(%w[branch Master remote])
    end

    it "retrieves variables from subsections including dots" do
      @config.set(%w[url git@github.com: insteadOf], "gh:")
      @config.save

      assert_equal "gh:", open_config.get(%w[url git@github.com: insteadOf])
    end

    it "retains the formatting of existing settings" do
      @config.set(%w[core Editor], "ed")
      @config.set(%w[user Name], "A. U. Thor")
      @config.set(%w[core Bare], true)
      @config.save

      config = open_config
      config.open_for_update
      config.set(%w[Core bare], false)
      config.save

      assert_file <<~CONFIG
        [core]
        \tEditor = ed
        \tbare = false
        [user]
        \tName = A. U. Thor
      CONFIG
    end
  end
end
