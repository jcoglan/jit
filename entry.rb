class Entry
  attr_reader :name, :oid

  REGULAR_MODE    = "100644"
  EXECUTABLE_MODE = "100755"
  DIRECTORY_MODE  = "40000"

  def initialize(name, oid, stat)
    @name = name
    @oid  = oid
    @stat = stat
  end

  def mode
    @stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
  end
end
