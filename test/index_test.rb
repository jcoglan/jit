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

  it "replaces a file with a directory" do
    index.add("alice.txt", oid, stat)
    index.add("bob.txt", oid, stat)

    index.add("alice.txt/nested.txt", oid, stat)

    assert_equal ["alice.txt/nested.txt", "bob.txt"],
                 index.each_entry.map(&:path)
  end

  it "replaces a directory with a file" do
    index.add("alice.txt", oid, stat)
    index.add("nested/bob.txt", oid, stat)

    index.add("nested", oid, stat)

    assert_equal ["alice.txt", "nested"],
                 index.each_entry.map(&:path)
  end

  it "recursively replaces a directory with a file" do
    index.add("alice.txt", oid, stat)
    index.add("nested/bob.txt", oid, stat)
    index.add("nested/inner/claire.txt", oid, stat)

    index.add("nested", oid, stat)

    assert_equal ["alice.txt", "nested"],
                 index.each_entry.map(&:path)
  end
end
