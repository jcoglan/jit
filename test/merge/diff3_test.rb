require "minitest/autorun"
require "merge/diff3"

describe Merge::Diff3 do
  it "cleanly merges two lists" do
    merge = Merge::Diff3.merge(%w[a b c], %w[d b c], %w[a b e])
    assert merge.clean?
    assert_equal "dbe", merge.to_s
  end

  it "cleanly merges two lists with the same edit" do
    merge = Merge::Diff3.merge(%w[a b c], %w[d b c], %w[d b e])
    assert merge.clean?
    assert_equal "dbe", merge.to_s
  end

  it "uncleanly merges two lists" do
    merge = Merge::Diff3.merge(%w[a b c], %w[d b c], %w[e b c])
    refute merge.clean?

    assert_equal <<~STR.strip, merge.to_s
      <<<<<<<
      d=======
      e>>>>>>>
      bc
    STR
  end

  it "uncleanly merges two lists against an empty list" do
    merge = Merge::Diff3.merge([], %w[d b c], %w[e b c])
    refute merge.clean?

    assert_equal <<~STR, merge.to_s
      <<<<<<<
      dbc=======
      ebc>>>>>>>
    STR
  end

  it "uncleanly merges two lists with head names" do
    merge = Merge::Diff3.merge(%w[a b c], %w[d b c], %w[e b c])
    refute merge.clean?

    assert_equal <<~STR.strip, merge.to_s("left", "right")
      <<<<<<< left
      d=======
      e>>>>>>> right
      bc
    STR
  end
end
