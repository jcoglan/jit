module Color
  SGR_CODES = {
    "normal"  =>  0,
    "bold"    =>  1,
    "dim"     =>  2,
    "italic"  =>  3,
    "ul"      =>  4,
    "reverse" =>  7,
    "strike"  =>  9,
    "black"   => 30,
    "red"     => 31,
    "green"   => 32,
    "yellow"  => 33,
    "blue"    => 34,
    "magenta" => 35,
    "cyan"    => 36,
    "white"   => 37
  }

  def self.format(style, string)
    codes = [*style].map { |name| SGR_CODES.fetch(name.to_s) }
    color = false

    codes.each_with_index do |code, i|
      next unless code >= 30
      codes[i] += 10 if color
      color = true
    end

    "\e[#{ codes.join(";") }m#{ string }\e[m"
  end
end
