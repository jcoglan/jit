require "minitest/autorun"
require "graph_helper"
require "merge/bases"
require "merge/common_ancestors"

describe Merge::CommonAncestors do
  include GraphHelper

  def ancestor(left, right)
    common = Merge::CommonAncestors.new(database, @commits[left], [@commits[right]])
    get_result(common)
  end

  def merge_base(left, right)
    bases = Merge::Bases.new(database, @commits[left], @commits[right])
    get_result(bases)
  end

  def get_result(common)
    commits = common.find.map { |oid| database.load(oid).message }
    commits.size == 1 ? commits.first : commits
  end

  describe "with a linear history" do

    #   o---o---o---o
    #   A   B   C   D

    before do
      chain [nil, "A", "B", "C", "D"]
    end

    it "finds the common ancestor of a commit with itself" do
      assert_equal "D", ancestor("D", "D")
    end

    it "finds the commit that is an ancestor of the other" do
      assert_equal "B", ancestor("B", "D")
    end

    it "find the same commit if the arguments are reversed" do
      assert_equal "B", ancestor("D", "B")
    end

    it "finds a root commit" do
      assert_equal "A", ancestor("A", "C")
    end

    it "finds the intersection of a root commit with itself" do
      assert_equal "A", ancestor("A", "A")
    end
  end

  describe "with a forking history" do

    #          E   F   G   H
    #          o---o---o---o
    #         /         \
    #        /  C   D    \
    #   o---o---o---o     o---o
    #   A   B    \        J   K
    #             \
    #              o---o---o
    #              L   M   N

    before do
      chain [nil, "A", "B", "C", "D"]
      chain ["B", "E", "F", "G", "H"]
      chain ["G", "J", "K"]
      chain ["C", "L", "M", "N"]
    end

    it "finds the nearest fork point" do
      assert_equal "G", ancestor("H", "K")
    end

    it "finds an ancestor multiple forks away" do
      assert_equal "B", ancestor("D", "K")
    end

    it "finds the same fork point for any point on a branch" do
      assert_equal "C", ancestor("D", "L")
      assert_equal "C", ancestor("M", "D")
      assert_equal "C", ancestor("D", "N")
    end

    it "finds the commit that is an ancestor of the other" do
      assert_equal "E", ancestor("K", "E")
    end

    it "finds a root commit" do
      assert_equal "A", ancestor("J", "A")
    end
  end

  describe "with a merge" do

    #   A   B   C   G   H
    #   o---o---o---o---o
    #        \     /
    #         o---o---o
    #         D   E   F

    before do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D", "E", "F"]
      commit ["C", "E"], "G"
      chain  ["G", "H"]
    end

    it "finds the most recent common ancestor" do
      assert_equal "E", ancestor("H", "F")
    end

    it "finds the common ancestor of a merge and its parents" do
      assert_equal "C", ancestor("C", "G")
      assert_equal "E", ancestor("G", "E")
    end
  end

  describe "with a merge further from one parent" do

    #   A   B   C   G   H   J
    #   o---o---o---o---o---o
    #        \     /
    #         o---o---o
    #         D   E   F

    before do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D", "E", "F"]
      commit ["C", "E"], "G"
      chain  ["G", "H", "J"]
    end

    it "finds all the common ancestors" do
      assert_equal ["E", "B"], ancestor("J", "F")
    end

    it "finds the best common ancestor" do
      assert_equal "E", merge_base("J", "F")
    end
  end

  describe "with commits between the common ancestor and the merge" do

    #   A   B   C       H   J
    #   o---o---o-------o---o
    #        \         /
    #         o---o---o G
    #         D  E \
    #               o F

    before do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D", "E", "F"]
      chain  ["E", "G"]
      commit ["C", "G"], "H"
      chain  ["H", "J"]
    end

    it "finds all the common ancestors" do
      assert_equal ["B", "E"], ancestor("J", "F")
    end

    it "finds the best common ancestor" do
      assert_equal "E", merge_base("J", "F")
    end
  end

  describe "with enough history to find all stale results" do

    #   A   B   C             H   J
    #   o---o---o-------------o---o
    #        \      E        /
    #         o-----o-------o
    #        D \     \     / G
    #           \     o   /
    #            \    F  /
    #             o-----o
    #             P     Q

    before do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D", "E", "F"]
      chain  ["D", "P", "Q"]
      commit ["E", "Q"], "G"
      commit ["C", "G"], "H"
      chain  ["H", "J"]
    end

    it "finds the best common ancestor" do
      assert_equal "E", ancestor("J", "F")
      assert_equal "E", ancestor("F", "J")
    end
  end

  describe "with many common ancestors" do

    #         L   M   N   P   Q   R   S   T
    #         o---o---o---o---o---o---o---o
    #        /       /       /       /
    #   o---o---o...o---o...o---o---o---o---o
    #   A   B  C \  D  E \  F  G \  H   J   K
    #             \       \       \
    #              o---o---o---o---o---o
    #              U   V   W   X   Y   Z

    before do
      chain  [nil, "A", "B", "C"] + (1..4).map { |n| "pad-1-#{n}" } +
             ["D", "E"] +           (1..4).map { |n| "pad-2-#{n}" } +
             ["F", "G"] +
             ["H", "J", "K"]

      chain  ["B", "L", "M"]
      commit ["M", "D"], "N"
      chain  ["N", "P"]
      commit ["P", "F"], "Q"
      chain  ["Q", "R"]
      commit ["R", "H"], "S"
      chain  ["S", "T"]

      chain  ["C", "U", "V"]
      commit ["V", "E"], "W"
      chain  ["W", "X"]
      commit ["X", "G"], "Y"
      chain  ["Y", "Z"]
    end

    it "finds multiple candidate common ancestors" do
      assert_equal ["G", "D", "B"], ancestor("T", "Z")
    end

    it "finds the best common ancestor" do
      assert_equal "G", merge_base("T", "Z")
    end
  end
end
