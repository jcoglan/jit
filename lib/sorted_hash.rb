class SortedHash < Hash
  def each
    keys.sort.each { |key| yield [key, self[key]] }
  end
end
