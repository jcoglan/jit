require "forwardable"

class Display
  SGR_CODES = {
    "bold"  =>  1,
    "red"   => 31,
    "green" => 32,
    "cyan"  => 36
  }

  extend Forwardable
  def_delegators :@stdout, :isatty, :puts

  attr_reader :stdout

  def initialize(stdout)
    @stdout = stdout
  end

  def fmt(style, string)
    return string unless @stdout.isatty

    code = SGR_CODES.fetch(style.to_s)
    "\e[#{ code }m#{ string }\e[m"
  end

  def close
  end
end
