module Color
  SGR_CODES = {
    "bold"   =>  1,
    "red"    => 31,
    "green"  => 32,
    "yellow" => 33,
    "cyan"   => 36
  }

  def self.format(style, string)
    codes = [*style].map { |name| SGR_CODES.fetch(name.to_s) }
    "\e[#{ codes.join(";") }m#{ string }\e[m"
  end
end
