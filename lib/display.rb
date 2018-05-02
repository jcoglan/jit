require "forwardable"

class Display
  SGR_CODES = {
    "bold"   =>  1,
    "red"    => 31,
    "green"  => 32,
    "yellow" => 33,
    "cyan"   => 36
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
    "\e[#{ codes.join(";") }m#{ string }\e[m"
  end

  def close
  end
end
