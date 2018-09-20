require "shellwords"

class Editor
  DEFAULT_EDITOR = "vi"

  def self.edit(path, command)
    editor = Editor.new(path, command)
    yield editor
    editor.edit_file
  end

  def initialize(path, command)
    @path    = path
    @command = command || DEFAULT_EDITOR
    @closed  = false
  end

  def puts(string)
    return if @closed
    file.puts(string)
  end

  def note(string)
    return if @closed
    string.each_line { |line| file.puts("# #{ line }") }
  end

  def close
    @closed = true
  end

  def edit_file
    file.close
    editor_argv = Shellwords.shellsplit(@command) + [@path.to_s]

    unless @closed or system(*editor_argv)
      raise "There was a problem with the editor '#{ @command }'."
    end

    remove_notes(File.read(@path))
  end

  private

  def remove_notes(string)
    lines = string.lines.reject { |line| line.start_with?("#") }

    if lines.all? { |line| /^\s*$/ =~ line }
      nil
    else
      "#{ lines.join("").strip }\n"
    end
  end

  def file
    flags = File::WRONLY | File::CREAT | File::TRUNC
    @file ||= File.open(@path, flags)
  end
end
