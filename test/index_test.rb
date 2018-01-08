require "minitest/autorun"

require "pathname"
require "securerandom"
require "index"

describe Index do
  let(:tmp_path)   { File.expand_path("../tmp", __FILE__) }
  let(:index_path) { Pathname.new(tmp_path).join("index") }
  let(:index)      { Index.new(index_path) }

  let(:stat) { File.stat(__FILE__) }
  let(:oid)  { SecureRandom.hex(20) }

  it "adds a single file" do
    index.add("alice.txt", oid, stat)

    assert_equal ["alice.txt"], index.each_entry.map(&:path)
  end
end
