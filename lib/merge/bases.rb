require "set"
require_relative "./common_ancestors"

module Merge
  class Bases

    def initialize(database, one, two)
      @database = database
      @common   = CommonAncestors.new(@database, one, [two])
    end

    def find
      @commits = @common.find
      return @commits if @commits.size <= 1

      @redundant = Set.new
      @commits.each { |commit| filter_commit(commit) }
      @commits - @redundant.to_a
    end

    private

    def filter_commit(commit)
      return if @redundant.include?(commit)

      others = @commits - [commit, *@redundant]
      common = CommonAncestors.new(@database, commit, others)

      common.find

      @redundant.add(commit) if common.marked?(commit, :parent2)

      others.select! { |oid| common.marked?(oid, :parent1) }
      @redundant.merge(others)
    end

  end
end
