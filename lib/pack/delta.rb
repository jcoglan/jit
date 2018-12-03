module Pack
  class Delta

    Copy   = Struct.new(:offset, :size)
    Insert = Struct.new(:data)

  end
end
