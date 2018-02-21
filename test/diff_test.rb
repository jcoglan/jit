require "minitest/autorun"
require "diff"

describe Diff do
  def hunks(a, b)
    Diff.diff_hunks(a, b).map { |hunk| [hunk.header, hunk.edits.map(&:to_s)] }
  end

  doc = %w[the quick brown fox jumps over the lazy dog]

  it "detects a deletion at the start" do
    changed = %w[quick brown fox jumps over the lazy dog]

    assert_equal [
      ["@@ -1,4 +1,3 @@", [
        "-the", " quick", " brown", " fox"
      ]]
    ], hunks(doc, changed)
  end

  it "detects an insertion at the start" do
    changed = %w[so the quick brown fox jumps over the lazy dog]

    assert_equal [
      ["@@ -1,3 +1,4 @@", [
        "+so", " the", " quick", " brown"
      ]]
    ], hunks(doc, changed)
  end

  it "detects a change skipping the start and end" do
    changed = %w[the quick brown fox leaps right over the lazy dog]

    assert_equal [
      ["@@ -2,7 +2,8 @@", [
        " quick", " brown", " fox", "-jumps", "+leaps", "+right", " over", " the", " lazy"
      ]]
    ], hunks(doc, changed)
  end

  it "puts nearby changes in the same hunk" do
    changed = %w[the brown fox jumps over the lazy cat]

    assert_equal [
      ["@@ -1,9 +1,8 @@", [
        " the", "-quick", " brown", " fox", " jumps", " over", " the", " lazy", "-dog", "+cat"
      ]]
    ], hunks(doc, changed)
  end

  it "puts distant changes in different hunks" do
    changed = %w[a quick brown fox jumps over the lazy cat]

    assert_equal [
      ["@@ -1,4 +1,4 @@", [
        "-the", "+a", " quick", " brown", " fox"
      ]],
      ["@@ -6,4 +6,4 @@", [
        " over", " the", " lazy", "-dog", "+cat"
      ]]
    ], hunks(doc, changed)
  end
end
