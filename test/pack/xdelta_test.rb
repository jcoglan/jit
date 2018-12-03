require "minitest/autorun"

require "pack"
require "pack/delta"
require "pack/xdelta"

#   0               16               32               48
#   +----------------+----------------+----------------+
#   |the quick brown |fox jumps over t|he slow lazy dog|
#   +----------------+----------------+----------------+

describe Pack::XDelta do
  def assert_delta(source, target, expected)
    delta  = Pack::XDelta.create_index(source)
    actual = delta.compress(target)

    assert_equal(expected, actual)
  end

  it "compresses a string" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "a swift auburn fox jumps over three dormant hounds"

    assert_delta source, target, [
      Pack::Delta::Insert.new("a swift aubur"),
      Pack::Delta::Copy.new(14, 19),
      Pack::Delta::Insert.new("ree dormant hounds")
    ]
  end

  it "compresses an incomplete block" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "he quick brown fox jumps over trees"

    assert_delta source, target, [
      Pack::Delta::Copy.new(1, 31),
      Pack::Delta::Insert.new("rees")
    ]
  end

  it "compresses as source start" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "the quick brown "

    assert_delta source, target, [
      Pack::Delta::Copy.new(0, 16)
    ]
  end

  it "compresses at source start with right expansion" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "the quick brown fox hops"

    assert_delta source, target, [
      Pack::Delta::Copy.new(0, 20),
      Pack::Delta::Insert.new("hops")
    ]
  end

  it "compresses at source start with left offset" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "behold the quick brown foal"

    assert_delta source, target, [
      Pack::Delta::Insert.new("behold "),
      Pack::Delta::Copy.new(0, 18),
      Pack::Delta::Insert.new("al")
    ]
  end

  it "compresses at source end" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "he slow lazy dog"

    assert_delta source, target, [
      Pack::Delta::Copy.new(32, 16)
    ]
  end

  it "compresses at source end with left expansion" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "under the slow lazy dog"

    assert_delta source, target, [
      Pack::Delta::Insert.new("und"),
      Pack::Delta::Copy.new(28, 20)
    ]
  end

  it "compresses at source end with right offset" do
    source = "the quick brown fox jumps over the slow lazy dog"
    target = "under the slow lazy dog's legs"

    assert_delta source, target, [
      Pack::Delta::Insert.new("und"),
      Pack::Delta::Copy.new(28, 20),
      Pack::Delta::Insert.new("'s legs")
    ]
  end

  it "compresses unindexed bytes" do
    source = "the quick brown fox"
    target = "see the quick brown fox"

    assert_delta source, target, [
      Pack::Delta::Insert.new("see "),
      Pack::Delta::Copy.new(0, 19)
    ]
  end

  it "does not compress unindexed bytes" do
    source = "the quick brown fox"
    target = "a quick brown fox"

    assert_delta source, target, [
      Pack::Delta::Insert.new("a quick brown fox")
    ]
  end
end
