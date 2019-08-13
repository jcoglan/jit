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

  def database
    @repo.database
  end

  def commit_time
    @time ||= Time.new(2018, 12, 25, 12, 0, 0)
    @time  += 1

    @time
  end

  def assert_graph(output)
    check_git_log(output)

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

  def check_git_log(output)
    FileUtils.cd @path do
      git_graph = `git log --format='%s' --graph #{ @commits.values.join(" ") }`
      assert_equal output, git_graph.gsub(/ *$/, "")
    end
  end

  def show_commit(graph, commit)
    graph.puts(commit.title_line)
  end

  def show_git
    FileUtils.cd @path do
      system "git", "log", "--graph", "--oneline", *@commits.values
    end
  end

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
      * | B
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
      | *   E
      | |\
      |/ /
      | * D
      * | C
      |/
      * B
      * A
    GRAPH
  end

  it "prints a merge where the first parent crosses" do
    chain  [nil, "A", "B", "C", "D"]
    commit ["D", "A"], "E"
    chain  ["B", "F"]
    chain  ["C", "G"]
    chain  ["D", "H"]

    assert_graph <<~'GRAPH'
      * H
      | * G
      | | * F
      | | | *   E
      | | | |\
      | |_|/ /
      |/| | |
      * | | | D
      |/ / /
      * | | C
      |/ /
      * | B
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
      * | B
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
      * | |   E
      |\ \ \
      | |/ /
      | * | C
      * | | D
      |/ /
      * | B
      |/
      * A
    GRAPH
  end

  it "prints a nested merge" do
    chain  [nil, "A", "B", "C"]
    chain  ["B", "D"]
    commit ["C", "D"], "E"
    commit ["E", "A"], "F"

    assert_graph <<~'GRAPH'
      *   F
      |\
      * \   E
      |\ \
      | * | D
      * | | C
      |/ /
      * | B
      |/
      * A
    GRAPH
  end

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
      | * | C
      | |/
      * | B
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
      * | | C
      |/ /
      * | B
      |/
      * A
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
      | | | *-.   E
      | | | |\ \
      | |_|/ / /
      |/| | | |
      | | | | * D
      | | | |/
      | | |/|
      | | | * C
      | | |/
      * | | B
      |/ /
      * | A
      |/
      * Z
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
      * | | C
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
      * | B
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
      * | B
      |/
      * A
    GRAPH
  end

  it "prints space around an octopus merge" do
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
      * | | C
      |/ /
      * | B
      |/
      * A
    GRAPH
  end

  it "prints a nested octopus merge" do
    chain  [nil, "A", "B", "C"]
    chain  ["B", "D"]
    chain  ["B", "E"]
    commit ["C", "D", "E"], "F"
    commit ["F", "A"], "G"

    assert_graph <<~'GRAPH'
      *   G
      |\
      | \
      |  \
      *-. \   F
      |\ \ \
      | | * | E
      | * | | D
      | |/ /
      * | | C
      |/ /
      * | B
      |/
      * A
    GRAPH
  end

  it "prints a nested octopus merge in the second column" do
    chain  [nil, "Y", "A", "B", "C"]
    chain  ["B", "D"]
    chain  ["B", "E"]
    commit ["C", "D", "E"], "F"
    commit ["F", "A"], "G"
    chain  ["Y", "Z"]

    assert_graph <<~'GRAPH'
      * Z
      | *   G
      | |\
      | | \
      | |  \
      | *-. \   F
      | |\ \ \
      | | | * | E
      | | * | | D
      | | |/ /
      | * | | C
      | |/ /
      | * | B
      | |/
      | * A
      |/
      * Y
    GRAPH
  end

  describe "with multiline output" do
    def show_commit(graph, commit)
      graph.puts("commit #{ commit.oid }")
      graph.puts(commit.author.name)
      graph.puts("")
      graph.puts("    #{ commit.title_line }")
      graph.puts("")
    end

    def check_git_log(*)
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
