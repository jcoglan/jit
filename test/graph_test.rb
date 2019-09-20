require "minitest/autorun"
require "fileutils"
require "pathname"
require "stringio"

require "graph"
require "graph_helper"
require "repository"
require "rev_list"

describe Graph do
  include GraphHelper

  before do
    @path = Pathname.new(File.expand_path("../test-repo", __FILE__))
    @repo = Repository.new(@path.join(".git"))

    FileUtils.mkdir_p(@path.join(".git", "objects"))
    FileUtils.mkdir_p(@path.join(".git", "refs"))

    @repo.refs.update_head("ref: #{ @repo.refs.default_ref.path }")
  end

  after do
    FileUtils.rm_rf(@path)
  end

  def check_impossible_history
    @commits.each_value do |oid|
      commit = @repo.database.load(oid)

      commit.parents.each_with_index do |poid, i|
        next if i == 0

        others = commit.parents.take(i)
        common = Merge::CommonAncestors.new(@repo.database, poid, others)
        next unless common.find.include?(poid)

        pname = @commits.key(poid)
        raise "impossible: commit #{ pname } is an ancestor"
      end
    end
  end

  def database
    @repo.database
  end

  def commit_time
    @time ||= Time.new(2018, 12, 25, 12, 0, 0)
    @time  += 1

    @time
  end

  def assert_graph(output)
    revs   = RevList.new(@repo, @commits.values, :sort => :topological)
    stdout = StringIO.new
    graph  = Graph.new(revs, stdout, false)

    revs.each do |commit|
      graph.update(commit)
      show_commit(graph, commit)
    end

    stdout.rewind
    assert_equal output, stdout.read.gsub(/ *$/, "")
  end

  def show_commit(graph, commit)
    graph.puts(commit.title_line)
  end

  def show_git
    FileUtils.cd @path do
      system "git", "log", "--graph", "--oneline", *@commits.values
    end
  end

  describe "histories with no merges" do
    it "prints a linear history" do
      chain [nil, "A", "B", "C"]

      assert_graph <<~'GRAPH'
        * C
        * B
        * A
      GRAPH
    end

    it "prints a fork" do
      chain [nil, "A", "B", "C"]
      chain ["B", "D"]

      assert_graph <<~'GRAPH'
        * D
        | * C
        |/
        * B
        * A
      GRAPH
    end

    it "prints multiple forks, stacked" do
      chain [nil, "A", "B", "C"]
      chain ["B", "D"]
      chain ["B", "E"]

      assert_graph <<~'GRAPH'
        * E
        | * D
        |/
        | * C
        |/
        * B
        * A
      GRAPH
    end

    it "prints branches, stacked" do
      chain [nil, "A", "B", "C"]
      chain ["B", "D", "E"]
      chain ["C", "F", "G"]
      chain ["C", "H", "J"]

      assert_graph <<~'GRAPH'
        * J
        * H
        | * G
        | * F
        |/
        * C
        | * E
        | * D
        |/
        * B
        * A
      GRAPH
    end

    it "prints branches, parallel" do
      chain [nil, "A", "B", "C", "D"]
      chain ["A", "E", "F"]
      chain ["B", "G", "H"]

      assert_graph <<~'GRAPH'
        * H
        * G
        | * F
        | * E
        | | * D
        | | * C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end

    it "prints branches, crossed" do
      chain [nil, "A", "B", "C", "D", "E"]
      chain ["C", "F"]
      chain ["A", "G"]
      chain ["B", "H"]
      chain ["D", "J"]

      assert_graph <<~'GRAPH'
        * J
        | * H
        | | * G
        | | | * F
        | | | | * E
        | |_|_|/
        |/| | |
        * | | | D
        | |_|/
        |/| |
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints branches, cascading cross" do
      chain [nil, "A", "B", "C", "D", "E"]
      chain ["B", "F"]
      chain ["C", "G"]
      chain ["A", "H"]
      chain ["D", "J"]

      assert_graph <<~'GRAPH'
        * J
        | * H
        | | * G
        | | | * F
        | | | | * E
        | |_|_|/
        |/| | |
        * | | | D
        | |/ /
        |/| |
        * | | C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end
  end

  describe "simple merges" do
    it "prints a trivial merge" do
      chain  [nil, "A", "B"]
      commit ["A", "B"], "C"

      assert_graph <<~'GRAPH'
        *   C
        |\
        | * B
        |/
        * A
      GRAPH
    end

    it "prints a non-trivial merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      commit ["C", "E"], "F"

      assert_graph <<~'GRAPH'
        *   F
        |\
        | * E
        | * D
        * | C
        * | B
        |/
        * A
      GRAPH
    end

    it "prints a non-trivial merge in the other order" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      commit ["E", "C"], "F"

      assert_graph <<~'GRAPH'
        *   F
        |\
        | * C
        | * B
        * | E
        * | D
        |/
        * A
      GRAPH
    end

    it "prints a merge in the second column" do
      chain  [nil, "Y", "A", "B", "C"]
      chain  ["A", "D", "E"]
      commit ["C", "E"], "F"
      chain  ["Y", "Z"]

      assert_graph <<~'GRAPH'
        * Z
        | *   F
        | |\
        | | * E
        | | * D
        | * | C
        | * | B
        | |/
        | * A
        |/
        * Y
      GRAPH
    end

    it "prints a merge with the first parent on the left" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      commit ["C", "D"], "E"
      chain  ["C", "F"]

      assert_graph <<~'GRAPH'
        * F
        | * E
        |/|
        | * D
        * | C
        |/
        * B
        * A
      GRAPH
    end

    it "prints a merge further right with the first parent on the left" do
      chain  [nil, "Y", "A", "B", "C"]
      chain  ["B", "D"]
      commit ["C", "D"], "E"
      chain  ["C", "F"]
      chain  ["Y", "Z"]

      assert_graph <<~'GRAPH'
        * Z
        | * F
        | | * E
        | |/|
        | | * D
        | * | C
        | |/
        | * B
        | * A
        |/
        * Y
      GRAPH
    end
  end

  describe "merges with crossing branches" do
    it "prints a merge where the first parent crosses" do
      chain  [nil, "A", "B", "C", "D"]
      chain  ["A", "E"]
      commit ["D", "E"], "F"
      chain  ["B", "G"]
      chain  ["C", "H"]
      chain  ["D", "J"]

      assert_graph <<~'GRAPH'
        * J
        | * H
        | | * G
        | | | * F
        | |_|/|
        |/| | |
        | | | * E
        * | | | D
        |/ / /
        * / / C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a merge where the first parent crosses two columns" do
      chain  [nil, "A", "B", "C", "D", "E"]
      chain  ["A", "F"]
      commit ["E", "F"], "G"
      chain  ["B", "H"]
      chain  ["C", "J"]
      chain  ["D", "K"]
      chain  ["E", "L"]

      assert_graph <<~'GRAPH'
        * L
        | * K
        | | * J
        | | | * H
        | | | | * G
        | |_|_|/|
        |/| | | |
        | | | | * F
        * | | | | E
        |/ / / /
        * / / / D
        |/ / /
        * / / C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a merge with the second parent on the left" do
      chain  [nil, "A", "B"]
      commit ["A", "B"], "C"
      chain  ["B", "D"]

      assert_graph <<~'GRAPH'
        * D
        | *   C
        | |\
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end

    it "prints a merge where the second parent crosses" do
      chain  [nil, "A", "B", "C"]
      commit ["A", "C"], "D"
      chain  ["B", "E"]
      chain  ["C", "F"]

      assert_graph <<~'GRAPH'
        * F
        | * E
        | | *   D
        | | |\
        | |_|/
        |/| |
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a merge with stacked branch" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      chain  ["A", "E"]
      commit ["C", "D"], "F"

      assert_graph <<~'GRAPH'
        *   F
        |\
        | * D
        * | C
        |/
        * B
        | * E
        |/
        * A
      GRAPH
    end

    it "prints a merge with crossing branch" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      chain  ["C", "E"]
      commit ["C", "D"], "F"

      assert_graph <<~'GRAPH'
        *   F
        |\
        | * D
        | | * E
        | |/
        |/|
        * | C
        |/
        * B
        * A
      GRAPH
    end

    it "prints a nested merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      chain  ["D", "F"]
      commit ["E", "F"], "G"
      commit ["G", "B"], "H"
      commit ["C", "H"], "J"

      assert_graph <<~'GRAPH'
        *   J
        |\
        | *   H
        | |\
        | * \   G
        | |\ \
        | | * | F
        | * | | E
        | |/ /
        | * | D
        * | | C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end
  end

  describe "octopus merges" do
    it "prints an octopus merge" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      chain  ["A", "E"]
      commit ["B", "C", "D", "E"], "F"

      assert_graph <<~'GRAPH'
        *---.   F
        |\ \ \
        | | | * E
        | | * | D
        | | |/
        | * / C
        | |/
        * / B
        |/
        * A
      GRAPH
    end

    it "prints an octopus merge with different start points" do
      chain  [nil, "A", "B", "C", "D"]
      chain  ["C", "E"]
      chain  ["B", "F"]
      chain  ["A", "G"]
      commit ["D", "E", "F", "G"], "H"

      assert_graph <<~'GRAPH'
        *---.   H
        |\ \ \
        | | | * G
        | | * | F
        | * | | E
        * | | | D
        |/ / /
        * / / C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints an octopus merge where the second parent crosses" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["A", "F"]
      chain  ["C", "G"]

      assert_graph <<~'GRAPH'
        * G
        | * F
        | | *-.   E
        | | |\ \
        | |_|/ /
        |/| | |
        | | | * D
        | | |/
        | |/|
        * / | C
        |/ /
        | * B
        |/
        * A
      GRAPH
    end

    it "prints an octopus merge where the third parent crosses" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["A", "F"]
      chain  ["D", "G"]

      assert_graph <<~'GRAPH'
        * G
        | * F
        | | *-.   E
        | | |\ \
        | |_|_|/
        |/| | |
        * | | | D
        |/ / /
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end

    it "prints an octopus merge where two parents cross" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      commit ["A", "C", "D"], "E"
      chain  ["D", "F"]
      chain  ["C", "G"]

      assert_graph <<~'GRAPH'
        * G
        | * F
        | | *-.   E
        | | |\ \
        | |_|/ /
        |/| | /
        | | |/
        | |/|
        | * | D
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints an octopus merge where two parents cross each other" do
      chain  [nil, "A", "B", "C", "D"]
      commit ["A", "C", "D"], "E"
      chain  ["B", "F"]
      chain  ["D", "G"]

      assert_graph <<~'GRAPH'
        * G
        | * F
        | | *-.   E
        | | |\ \
        | |_|_|/
        |/| | |
        * | | | D
        | |_|/
        |/| |
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a nested octopus merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      chain  ["B", "E"]
      commit ["C", "D", "E"], "F"
      chain  ["A", "G"]
      commit ["F", "G"], "H"

      assert_graph <<~'GRAPH'
        *   H
        |\
        | * G
        | |
        |  \
        *-. \   F
        |\ \ \
        | | * | E
        | * | | D
        | |/ /
        * / / C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a nested octopus merge in the second column" do
      chain  [nil, "Y", "A", "B", "C"]
      chain  ["B", "D"]
      chain  ["B", "E"]
      commit ["C", "D", "E"], "F"
      chain  ["A", "G"]
      commit ["F", "G"], "H"
      chain  ["Y", "Z"]

      assert_graph <<~'GRAPH'
        * Z
        | *   H
        | |\
        | | * G
        | | |
        | |  \
        | *-. \   F
        | |\ \ \
        | | | * | E
        | | * | | D
        | | |/ /
        | * / / C
        | |/ /
        | * / B
        | |/
        | * A
        |/
        * Y
      GRAPH
    end

    it "prints an octopus merge where the first parent crosses" do
      chain  [nil, "Z", "A", "B"]
      chain  ["Z", "C"]
      chain  ["Z", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["Z", "F"]
      chain  ["A", "G"]
      chain  ["B", "H"]

      assert_graph <<~'GRAPH'
        * H
        | * G
        | | * F
        | | | *   E
        | |_|/|\
        |/| | | |
        | | | | * D
        | | | |/
        | | |/|
        | | | * C
        | | |/
        * | / B
        |/ /
        * / A
        |/
        * Z
      GRAPH
    end

    it "prints a nested left-skewed octopus merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      chain  ["D", "F"]
      chain  ["D", "G"]
      commit ["E", "F", "G"], "H"
      commit ["H", "B"], "J"
      commit ["E", "J"], "K"
      commit ["C", "K"], "L"

      assert_graph <<~'GRAPH'
        *   L
        |\
        | *   K
        | |\
        | | *   J
        | | |\
        | | * \   H
        | |/|\ \
        | | | * | G
        | | * | | F
        | | |/ /
        | * / / E
        | |/ /
        | * | D
        * | | C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end

    it "prints space around a right-joined octopus merge" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["D", "F"]
      commit ["E", "F"], "G"

      assert_graph <<~'GRAPH'
        *   G
        |\
        | * F
        | |
        |  \
        *-. | E
        |\ \|
        | | * D
        | * | C
        | |/
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a left-tracking edge under a left-skewed octopus merge" do
      chain  [nil, "A", "B", "C", "D", "E"]
      commit ["D", "C", "B"], "F"
      commit ["D", "F"], "G"
      commit ["E", "G"], "H"
      chain  ["A", "J"]

      # todo possibly fix line E

      assert_graph <<~'GRAPH'
        * J
        | *   H
        | |\
        | | *   G
        | | |\
        | | | *   F
        | | |/|\
        | * | | | E
        | |/ / /
        | * / / D
        | |/ /
        | * / C
        | |/
        | * B
        |/
        * A
      GRAPH
    end
  end

  describe "stacked merges" do
    it "prints a merge nested under an octopus merge" do
      chain  [nil, "A", "B", "C", "D"]
      chain  ["B", "E", "F"]
      chain  ["A", "G", "H"]
      commit ["G", "H"], "J"
      commit ["J", "C", "E"], "K"
      commit ["F", "K"], "L"
      commit ["D", "L"], "M"

      assert_graph <<~'GRAPH'
        *   M
        |\
        | *   L
        | |\
        | | *-.   K
        | | |\ \
        | | * \ \   J
        | | |\ \ \
        | | | * | | H
        | | |/ / /
        | | * | | G
        | * | | | F
        | | |_|/
        | |/| |
        | * | | E
        * | | | D
        | |_|/
        |/| |
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a merge nested to the left of an octopus merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      chain  ["A", "F", "G"]
      commit ["E", "G"], "H"
      commit ["F", "D", "B"], "J"
      commit ["H", "J"], "K"
      commit ["C", "K"], "L"

      assert_graph <<~'GRAPH'
        *   L
        |\
        | *   K
        | |\
        | | *-.   J
        | | |\ \
        | * | \ \   H
        | |\ \ \ \
        | | * | | | G
        | | |/ / /
        | | * | | F
        | * | | | E
        | | |/ /
        | |/| |
        | * | | D
        | |/ /
        * | / C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end
  end

  describe "flattening graphs to the left and right" do
    it "prints a merge with snaking branches" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      commit ["D", "C"], "E"
      chain  ["A", "F"]
      commit ["C", "F"], "G"
      commit ["E", "G"], "H"

      assert_graph <<~'GRAPH'
        *   H
        |\
        | *   G
        | |\
        | | * F
        * | | E
        |\| |
        | * | C
        * | | D
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a nested left-skewed merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["B", "D"]
      commit ["C", "D"], "E"
      chain  ["A", "F"]
      commit ["E", "F"], "G"
      chain  ["C", "H"]

      assert_graph <<~'GRAPH'
        * H
        | *   G
        | |\
        | | * F
        | * | E
        |/| |
        | * | D
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a left-skewed right-joined merge" do
      chain  [nil, "A", "B"]
      chain  ["A", "C", "E"]
      commit ["B", "C"], "D"
      commit ["D", "E"], "F"
      commit ["B", "F"], "G"

      assert_graph <<~'GRAPH'
        *   G
        |\
        | *   F
        | |\
        | | * E
        | * | D
        |/| |
        | |/
        | * C
        * | B
        |/
        * A
      GRAPH
    end

    it "prints a nested right-skewed merge after a left-skewed one (1)" do
      chain  [nil, "A", "B", "F"]
      chain  ["A", "C"]
      commit ["B", "C"], "D"
      commit ["A", "D"], "E"
      commit ["E", "F"], "G"
      chain  ["A", "H"]

      assert_graph <<~'GRAPH'
        * H
        | *   G
        | |\
        | | * F
        | * | E
        |/| |
        | * |   D
        | |\ \
        | | |/
        | |/|
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end

    it "prints a nested right-skewed merge after a left-skewed one (2)" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      commit ["B", "C"], "D"
      commit ["A", "D"], "E"
      chain  ["C", "F"]
      commit ["E", "F"], "G"
      chain  ["A", "H"]

      assert_graph <<~'GRAPH'
        * H
        | *   G
        | |\
        | | * F
        | * | E
        |/| |
        | * | D
        | |\|
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end
  end

  describe "stacking left-skewed octopus merges" do
    it "prints a left-skewed merge under a left-skewed octopus merge" do
      chain  [nil, "A", "B", "C", "D"]
      chain  ["B", "E", "F"]
      chain  ["A", "G", "H"]
      commit ["G", "H"], "J"
      commit ["J", "E", "C"], "K"
      commit ["G", "J", "K"], "L"
      commit ["F", "L"], "M"
      commit ["D", "M"], "N"

      assert_graph <<~'GRAPH'
        *   N
        |\
        | *   M
        | |\
        | | *-.   L
        | | |\ \
        | | | | *   K
        | | | |/|\
        | | | * | | J
        | | |/| | |
        | | | * | | H
        | | |/ / /
        | | * | | G
        | * | | | F
        | | |/ /
        | |/| |
        | * | | E
        * | | | D
        | |_|/
        |/| |
        * | | C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a left-skewed merge under a left-skewed octopus merge with concurrent parents" do
      chain  [nil, "A", "B", "C", "D", "E"]
      chain  ["C", "F", "G"]
      chain  ["A", "H"]
      commit ["B", "H"], "J"
      commit ["J", "F", "D"], "K"
      commit ["J", "K"], "L"
      commit ["B", "L"], "M"
      commit ["G", "M"], "N"
      commit ["E", "N"], "P"

      assert_graph <<~'GRAPH'
        *   P
        |\
        | *   N
        | |\
        | | *   M
        | | |\
        | | | *   L
        | | | |\
        | | | | *   K
        | | | |/|\
        | | | * | | J
        | | |/| | |
        | | | * | | H
        | * | | | | G
        | | |_|/ /
        | |/| | |
        | * | | | F
        * | | | | E
        | |_|_|/
        |/| | |
        * | | | D
        |/ / /
        * / / C
        |/ /
        * / B
        |/
        * A
      GRAPH
    end

    it "prints a left-skewed merge under a left-skewed octopus merge with more recent parents" do
      chain  [nil, "A", "B", "C"]
      commit ["A", "C"], "D"
      chain  ["C", "E"]
      chain  ["B", "F"]
      commit ["D", "E", "F"], "G"
      chain  ["D", "H"]
      chain  ["A", "J"]

      assert_graph <<~'GRAPH'
        * J
        | * H
        | | *   G
        | |/|\
        | | | * F
        | | * | E
        | * | | D
        |/| | |
        | |/ /
        | * / C
        | |/
        | * B
        |/
        * A
      GRAPH
    end
  end

  describe "stacked octopus and right-joining merges" do
    it "prints a merge nested under a right-joined octopus merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      chain  ["A", "F", "G"]
      commit ["F", "G"], "H"
      commit ["H", "D", "B"], "J"
      chain  ["B", "K"]
      commit ["J", "K"], "L"
      commit ["E", "L"], "M"
      commit ["C", "M"], "N"

      # todo fix line H

      assert_graph <<~'GRAPH'
        *   N
        |\
        | *   M
        | |\
        | | *   L
        | | |\
        | | | * K
        | | | |
        | | |  \
        | | *-. | J
        | | |\ \|
        | | * | |   H
        | | |\ \ \
        | | | * | | G
        | | |/ / /
        | | * | | F
        | * | | | E
        | | |/ /
        | |/| |
        | * | | D
        | |/ /
        * | / C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end

    it "prints a right-joined merge to the left of an octopus merge" do
      chain  [nil, "A", "B", "C"]
      chain  ["A", "D", "E"]
      chain  ["D", "F"]
      commit ["E", "F"], "G"
      commit ["F", "E", "B"], "H"
      commit ["G", "H"], "J"
      commit ["C", "J"], "K"

      assert_graph <<~'GRAPH'
        *   K
        |\
        | *   J
        | |\
        | | *-.   H
        | | |\ \
        | * | | | G
        | |\| | |
        | | |/ /
        | |/| |
        | | * | F
        | * | | E
        | |/ /
        | * | D
        * | | C
        | |/
        |/|
        * | B
        |/
        * A
      GRAPH
    end
  end

  describe "octopus merges with a column to the right matching a non-final parent" do
    it "prints a merge with two crossing parents" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      commit ["D", "C"], "F"

      assert_graph <<~'GRAPH'
        *   F
        |\
        | | *-.   E
        | | |\ \
        | | |/ /
        | |/| /
        | |_|/
        |/| |
        * | | D
        | * | C
        |/ /
        | * B
        |/
        * A
      GRAPH
    end

    it "prints a merge with a column matching the penultimate parent" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["C", "F"]
      commit ["E", "F"], "G"
      chain  ["D", "H"]

      assert_graph <<~'GRAPH'
        * H
        | *   G
        | |\
        | | * F
        | | |
        | |  \
        | *-. \   E
        | |\ \ \
        | |_|/ /
        |/| | /
        | | |/
        * | | D
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end

    it "prints a left-skewed merge whose last parent crosses" do
      chain  [nil, "A", "B"]
      chain  ["A", "C", "D"]
      chain  ["A", "E"]
      commit ["B", "D", "E"], "F"
      chain  ["C", "G"]
      commit ["E", "B", "F", "G"], "H"

      assert_graph <<~'GRAPH'
        *---.   H
        |\ \ \
        | | | * G
        | | * |   F
        | |/|\ \
        | |_|/ /
        |/| | |
        * | | | E
        | | * | D
        | | |/
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end

    it "prints a left-skewed merge with a column matching the penultimate parent" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      chain  ["A", "D"]
      commit ["B", "C", "D"], "E"
      chain  ["C", "F"]
      commit ["D", "B", "E", "F"], "G"

      assert_graph <<~'GRAPH'
        *---.   G
        |\ \ \
        | | | * F
        | | * |   E
        | |/|\ \
        | |_|/ /
        |/| | /
        | | |/
        * | | D
        | | * C
        | |/
        |/|
        | * B
        |/
        * A
      GRAPH
    end
  end

  describe "multiline output" do
    def show_commit(graph, commit)
      graph.puts("commit #{ commit.oid }")
      graph.puts(commit.author.name)
      graph.puts("")
      graph.puts("    #{ commit.title_line }")
      graph.puts("")
    end

    it "prints the commit graph" do
      chain  [nil, "A", "B"]
      chain  ["A", "C"]
      commit ["B", "C"], "D"
      commit ["D", "A"], "E"

      assert_graph <<~'GRAPH'
        *   commit 9af2a4fbf39b819a2a8bfe962ca6ee16e493854f
        |\  A. U. Thor
        | |
        | |     E
        | |
        * |   commit 839c377b595324602d273a72fdc96df0b7ff9104
        |\ \  A. U. Thor
        | | |
        | | |     D
        | | |
        | * | commit a2923f328780df787ecafa5989b3793abb423b9b
        | |/  A. U. Thor
        | |
        | |       C
        | |
        * | commit 7bfcac73f5d9b2bd51f909931279f74a434fa366
        |/  A. U. Thor
        |
        |       B
        |
        * commit 44346420279d81bc62b15eefc8864b0852bfae4f
          A. U. Thor

              A

      GRAPH
    end
  end
end
