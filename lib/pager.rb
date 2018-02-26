class Pager
  PAGER_CMD = "less"
  PAGER_ENV = { "LESS" => "FRX", "LV" => "-c" }

  attr_reader :input

  def initialize(env = {}, stdout = $stdout, stderr = $stderr)
    env = PAGER_ENV.merge(env)
    cmd = env["GIT_PAGER"] || env["PAGER"] || PAGER_CMD

    reader, writer = IO.pipe
    options = { :in => reader, :out => stdout, :err => stderr }

    @pid   = Process.spawn(env, cmd, options)
    @input = writer

    reader.close
  end

  def wait
    Process.waitpid(@pid) if @pid
    @pid = nil
  end
end
