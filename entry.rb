class Entry
  attr_reader :name, :oid

  def initialize(name, oid)
    @name = name
    @oid  = oid
  end
end
