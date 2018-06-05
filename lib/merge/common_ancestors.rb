require "set"

module Merge
  class CommonAncestors

    BOTH_PARENTS = Set.new([:parent1, :parent2])

    def initialize(database, one, two)
      @database = database
      @flags    = Hash.new { |hash, oid| hash[oid] = Set.new }
      @queue    = []

      insert_by_date(@queue, @database.load(one))
      @flags[one].add(:parent1)

      insert_by_date(@queue, @database.load(two))
      @flags[two].add(:parent2)
    end

    def find
      until @queue.empty?
        commit = @queue.shift
        flags  = @flags[commit.oid]

        return commit.oid if flags == BOTH_PARENTS

        add_parents(commit, flags)
      end
    end

    private

    def add_parents(commit, flags)
      return unless commit.parent

      parent = @database.load(commit.parent)
      return if @flags[parent.oid].superset?(flags)

      @flags[parent.oid].merge(flags)
      insert_by_date(@queue, parent)
    end

    def insert_by_date(list, commit)
      index = list.find_index { |c| c.date < commit.date }
      list.insert(index || list.size, commit)
    end

  end
end
