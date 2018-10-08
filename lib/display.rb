require "forwardable"

class Display
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

  extend Forwardable
  def_delegators :@stdout, :isatty, :puts

  attr_reader :stdout

  def initialize(stdout)
    @stdout = stdout
  end

  def fmt(style, string)
    return string unless @stdout.isatty

    codes = [*style].map { |name| SGR_CODES.fetch(name.to_s) }
    color = false

    codes.each_with_index do |code, i|
      next unless code >= 30
      codes[i] += 10 if color
      color = true
    end

    "\e[#{ codes.join(";") }m#{ string }\e[m"
  end

  def close
  end
end
