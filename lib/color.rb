module Color
  SGR_CODES = {
    "bold"   =>  1,
    "red"    => 31,
    "green"  => 32,
    "yellow" => 33,
    "cyan"   => 36
  }

  def self.format(style, string)
    code = SGR_CODES.fetch(style.to_s)
    "\e[#{ code }m#{ string }\e[m"
  end
end
