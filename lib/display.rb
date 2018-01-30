require "forwardable"

class Display
  SGR_CODES = {
    "red"   => 31,
    "green" => 32
  }

  extend Forwardable
  def_delegators :@stdout, :puts

  def initialize(stdout)
    @stdout = stdout
  end

  def fmt(style, string)
    return string unless @stdout.isatty

    code = SGR_CODES.fetch(style.to_s)
    "\e[#{ code }m#{ string }\e[m"
  end
end

