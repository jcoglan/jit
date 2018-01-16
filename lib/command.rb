require_relative "./command/add"
require_relative "./command/commit"
require_relative "./command/init"

module Command
  Unknown = Class.new(StandardError)

  COMMANDS = {
    "init"   => Init,
    "add"    => Add,
    "commit" => Commit
  }

  def self.execute(name)
    unless COMMANDS.has_key?(name)
      raise Unknown, "'#{ name }' is not a jit command."
    end

    command_class = COMMANDS[name]
    command_class.new.run
  end
end
