require "set"

class SortedHash < Hash
  def initialize
    super
    @keys = SortedSet.new
  end

  def []=(key, value)
    @keys.add(key)
    super
  end

  def each
    @keys.each { |key| yield [key, self[key]] }
  end
end
