module Color
  SGR_CODES = {
    "red"   => 31,
    "green" => 32
  }

  def self.format(style, string)
    code = SGR_CODES.fetch(style.to_s)
    "\e[#{ code }m#{ string }\e[m"
  end
end
