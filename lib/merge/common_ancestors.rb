require "set"

module Merge
  class CommonAncestors

    BOTH_PARENTS = Set.new([:parent1, :parent2])

    def initialize(database, one, twos)
      @database = database
      @flags    = Hash.new { |hash, oid| hash[oid] = Set.new }
      @queue    = []
      @results  = []

      insert_by_date(@queue, @database.load(one))
      @flags[one].add(:parent1)

      twos.each do |two|
        insert_by_date(@queue, @database.load(two))
        @flags[two].add(:parent2)
      end
    end

    def find
      process_queue until all_stale?
      @results.map(&:oid).reject { |oid| marked?(oid, :stale) }
    end

    def marked?(oid, flag)
      @flags[oid].include?(flag)
    end

    private

    def all_stale?
      @queue.all? { |commit| marked?(commit.oid, :stale) }
    end

    def process_queue
      commit = @queue.shift
      flags  = @flags[commit.oid]

      if flags == BOTH_PARENTS
        flags.add(:result)
        insert_by_date(@results, commit)
        add_parents(commit, flags + [:stale])
      else
        add_parents(commit, flags)
      end
    end

    def add_parents(commit, flags)
      commit.parents.each do |parent|
        next if @flags[parent].superset?(flags)

        @flags[parent].merge(flags)
        insert_by_date(@queue, @database.load(parent))
      end
    end

    def insert_by_date(list, commit)
      index = list.find_index { |c| c.date < commit.date }
      list.insert(index || list.size, commit)
    end

  end
end
