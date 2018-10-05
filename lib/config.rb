require_relative "./lockfile"

class Config
  SECTION_LINE  = /^\s*\[([a-z0-9-]+)( "(.+)")?\]\s*($|#|;)/i
  VARIABLE_LINE = /^\s*([a-z][a-z0-9-]*)\s*=\s*(.*?)\s*($|#|;)/i
  BLANK_LINE    = /^\s*($|#|;)/
  INTEGER       = /^-?[1-9][0-9]*$/

  VALID_SECTION  = /^[a-z0-9-]+$/i
  VALID_VARIABLE = /^[a-z][a-z0-9-]*$/i

  Conflict   = Class.new(StandardError)
  ParseError = Class.new(StandardError)

  Line = Struct.new(:text, :section, :variable) do
    def normal_variable
      Variable.normalize(variable&.name)
    end
  end

  Section = Struct.new(:name) do
    def self.normalize(name)
      return [] if name.empty?
      [name.first.downcase, name.drop(1).join(".")]
    end

    def headling_line
      line = "[#{ name.first }"
      line.concat(%' "#{ name.drop(1).join(".") }"') if name.size > 1
      line.concat("]\n")
    end
  end

  Variable = Struct.new(:name, :value) do
    def self.normalize(name)
      name&.downcase
    end

    def self.serialize(name, value)
      "\t#{ name } = #{ value }\n"
    end
  end

  def self.valid_key?(key)
    VALID_SECTION =~ key.first and VALID_VARIABLE =~ key.last
  end

  def initialize(path)
    @path     = path
    @lockfile = Lockfile.new(path)
    @lines    = nil
  end

  def open
    read_config_file unless @lines
  end

  def open_for_update
    @lockfile.hold_for_update
    read_config_file
  end

  def save
    @lines.each do |section, lines|
      lines.each { |line| @lockfile.write(line.text) }
    end
    @lockfile.commit
  end

  def get(key)
    get_all(key).last
  end

  def get_all(key)
    key, var = split_key(key)
    _, lines = find_lines(key, var)

    lines.map { |line| line.variable.value }
  end

  def add(key, value)
    key, var   = split_key(key)
    section, _ = find_lines(key, var)

    add_variable(section, key, var, value)
  end

  def set(key, value)
    key, var       = split_key(key)
    section, lines = find_lines(key, var)

    case lines.size
    when 0 then add_variable(section, key, var, value)
    when 1 then update_variable(lines.first, var, value)
    else
      message = "cannot overwrite multiple values with a single value"
      raise Conflict, message
    end
  end

  def replace_all(key, value)
    key, var       = split_key(key)
    section, lines = find_lines(key, var)

    remove_all(section, lines)
    add_variable(section, key, var, value)
  end

  private

  def line_count
    @lines.each_value.reduce(0) { |n, lines| n + lines.size }
  end

  def lines_for(section)
    @lines[Section.normalize(section.name)]
  end

  def split_key(key)
    key = key.map(&:to_s)
    var = key.pop

    [key, var]
  end

  def find_lines(key, var)
    name = Section.normalize(key)
    return [nil, []] unless @lines.has_key?(name)

    lines   = @lines[name]
    section = lines.first.section
    normal  = Variable.normalize(var)

    lines = lines.select { |l| normal == l.normal_variable }
    [section, lines]
  end

  def add_section(key)
    section = Section.new(key)
    line    = Line.new(section.headling_line, section)

    lines_for(section).push(line)
    section
  end

  def add_variable(section, key, var, value)
    section ||= add_section(key)

    text = Variable.serialize(var, value)
    var  = Variable.new(var, value)
    line = Line.new(text, section, var)

    lines_for(section).push(line)
  end

  def update_variable(line, var, value)
    line.variable.value = value
    line.text = Variable.serialize(var, value)
  end

  def remove_all(section, lines)
    lines.each { |line| lines_for(section).delete(line) }
  end

  def read_config_file
    @lines  = Hash.new { |hash, key| hash[key] = [] }
    section = Section.new([])

    File.open(@path, File::RDONLY) do |file|
      until file.eof?
        line    = parse_line(section, file.readline)
        section = line.section

        lines_for(section).push(line)
      end
    end
  rescue Errno::ENOENT
  end

  def parse_line(section, line)
    if match = SECTION_LINE.match(line)
      section = Section.new([match[1], match[3]].compact)
      Line.new(line, section)
    elsif match = VARIABLE_LINE.match(line)
      variable = Variable.new(match[1], parse_value(match[2]))
      Line.new(line, section, variable)
    elsif match = BLANK_LINE.match(line)
      Line.new(line, section, nil)
    else
      message = "bad config line #{ line_count + 1 } in file #{ @path }"
      raise ParseError, message
    end
  end

  def parse_value(value)
    case value
    when "yes", "on", "true"  then true
    when "no", "off", "false" then false
    when INTEGER              then value.to_i
    else                           value
    end
  end
end
