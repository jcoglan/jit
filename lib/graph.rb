require "forwardable"

require_relative "./color"
require_relative "./graph/buffer"

class Graph
  COLORS = [
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    [:bold, :red],
    [:bold, :green],
    [:bold, :yellow],
    [:bold, :blue],
    [:bold, :magenta],
    [:bold, :cyan]
  ]

  Column = Struct.new(:commit, :color)

  extend Forwardable
  def_delegators :@output, :close_write

  def initialize(rev_list, output, isatty)
    @rev_list = rev_list
    @output   = output
    @commit   = nil

    @expansion_row = 0
    @num_parents   = 0
    @width         = 0

    @colors = isatty ? COLORS : []
    @color  = @colors.size - 1

    @state = @prev_state = :padding
    @commit_index = @prev_commit_index = 0

    @columns = @new_columns = []
    @mapping = []
  end

  def update(commit)
    puts_next_line until @state == :padding
    update_commit(commit)
    puts_next_line until @state == :commit
  end

  def puts(string)
    buffer = Buffer.new
    output_next_line(buffer)
    @output.write(buffer.data)
    @output.puts(string)
  end

  private

  def puts_next_line
    buffer = Buffer.new
    output_next_line(buffer)
    @output.puts(buffer.data)
  end

  def update_commit(commit)
    @commit = commit
    @num_parents = @rev_list.parents(commit).size

    @prev_commit_index = @commit_index
    update_columns
    @expansion_row = 0

    if @state != :padding
      @state = :skip
    elsif @num_parents >= 3 and @commit_index < @columns.size - 1
      @state = :pre_commit
    else
      @state = :commit
    end
  end

  def update_columns
    @columns     = @new_columns
    @new_columns = []
    @mapping     = []
    @width       = 0

    seen_this  = false
    in_columns = true

    (0 .. @columns.size).each do |i|
      if i == @columns.size
        break if seen_this
        in_columns = false
        col_commit = @commit
      else
        col_commit = @columns[i].commit
      end

      unless col_commit == @commit
        insert_into_new_columns(col_commit)
        next
      end

      seen_this = true
      @commit_index = i
      @width += 2 if @num_parents == 0

      @rev_list.parents(@commit).each do |parent|
        increment_column_color if @num_parents > 1 or not in_columns
        insert_into_new_columns(parent)
      end
    end
  end

  def insert_into_new_columns(commit)
    idx = @new_columns.find_index { |col| col.commit == commit }

    unless idx
      idx = @new_columns.size
      column = Column.new(commit, find_commit_color(commit))
      @new_columns.push(column)
    end

    @mapping[@width] = idx
    @width += 2
  end

  def increment_column_color
    @color = (@color + 1) % @colors.size unless @color == -1
  end

  def find_commit_color(commit)
    column = @columns.find { |col| col.commit == commit }
    column ? column.color : @colors[@color]
  end

  def update_state(state)
    @prev_state = @state
    @state = state
  end

  def output_next_line(buffer)
    case @state
    when :padding    then output_padding_line(buffer)
    when :skip       then output_skip_line(buffer)
    when :pre_commit then output_pre_commit_line(buffer)
    when :commit     then output_commit_line(buffer)
    when :post_merge then output_post_merge_line(buffer)
    when :collapsing then output_collapsing_line(buffer)
    end

    buffer.pad(@width)
  end

  def output_padding_line(buffer)
    return unless @commit

    @new_columns.each do |column|
      buffer.write_column(column, "|")
      buffer.write(" ")
    end

    @prev_state = :padding
  end

  def output_skip_line(buffer)
    buffer.write("...")

    if @num_parents >= 3 and @commit_index < @columns.size - 1
      update_state(:pre_commit)
    else
      update_state(:commit)
    end
  end

  def output_pre_commit_line(buffer)
    num_expansion_rows = 2 * (@num_parents - 2)
    seen_this = false

    @columns.each_with_index do |column, i|
      if column.commit == @commit
        seen_this = true
        buffer.write_column(column, "|")
        buffer.write(" " * @expansion_row)
      elsif seen_this and @expansion_row == 0
        if @prev_state == :post_merge and @prev_commit_index < i
          buffer.write_column(column, "\\")
        else
          buffer.write_column(column, "|")
        end
      elsif seen_this and @expansion_row > 0
        buffer.write_column(column, "\\")
      else
        buffer.write_column(column, "|")
      end
      buffer.write(" ")
    end

    @expansion_row += 1

    if @expansion_row >= num_expansion_rows
      update_state(:commit)
    end
  end

  def output_commit_line(buffer)
    seen_this = false

    (0 .. @columns.size).each do |i|
      column = @columns[i]

      if i == @columns.size
        break if seen_this
        col_commit = @commit
      else
        col_commit = @columns[i].commit
      end

      if col_commit == @commit
        seen_this = true
        buffer.write("*")
        draw_octopus_merge(buffer) if @num_parents > 2
      elsif seen_this and @num_parents > 2
        buffer.write_column(column, "\\")
      elsif seen_this and @num_parents == 2
        if @prev_state == :post_merge and @prev_commit_index < i
          buffer.write_column(column, "\\")
        else
          buffer.write_column(column, "|")
        end
      else
        buffer.write_column(column, "|")
      end
      buffer.write(" ")
    end

    if @num_parents > 1
      update_state(:post_merge)
    elsif mapping_correct?
      update_state(:padding)
    else
      update_state(:collapsing)
    end
  end

  def draw_octopus_merge(buffer)
    dashless_parents  = 2
    dashful_parents   = @num_parents - dashless_parents
    added_columns     = @new_columns.size - @columns.size
    parent_in_columns = @num_parents - added_columns
    first_column      = @commit_index + dashless_parents - parent_in_columns

    (0 ... dashful_parents).each do |i|
      buffer.write_column(@new_columns[i + first_column], "-")
      ch = (i == dashful_parents - 1) ? "." : "-"
      buffer.write_column(@new_columns[i + first_column], ch)
    end
  end

  def output_post_merge_line(buffer)
    seen_this = false

    (0 .. @columns.size).each do |i|
      column = @columns[i]

      if i == @columns.size
        break if seen_this
        col_commit = @commit
      else
        col_commit = column.commit
      end

      if col_commit == @commit
        seen_this = true
        parents = @rev_list.parents(@commit)

        par_column = find_new_column_by_commit(parents.first)
        buffer.write_column(par_column, "|")

        parents.drop(1).each do |parent|
          par_column = find_new_column_by_commit(parent)
          buffer.write_column(par_column, "\\")
          buffer.write(" ")
        end

      elsif seen_this
        buffer.write_column(column, "\\")
        buffer.write(" ")
      else
        buffer.write_column(column, "|")
        buffer.write(" ")
      end
    end

    if mapping_correct?
      update_state(:padding)
    else
      update_state(:collapsing)
    end
  end

  def find_new_column_by_commit(commit)
    @new_columns.find { |column| column.commit == commit }
  end

  def output_collapsing_line(buffer)
    used_horizontal   = false
    horiz_edge        = -1
    horiz_edge_target = -1

    new_mapping = []

    @mapping.each_with_index do |target, i|
      next unless target

      if 2 * target == i
        new_mapping[i] = target
      elsif new_mapping[i - 1] == nil
        new_mapping[i - 1] = target
        if horiz_edge == -1
          horiz_edge = i
          horiz_edge_target = target
          (2 * target + 3 ... i - 2).step(2) { |j| new_mapping[j] = target }
        end
      elsif new_mapping[i - 1] != target
        new_mapping[i - 2] = target
        horiz_edge = i if horiz_edge == -1
      end
    end

    new_mapping.each_with_index do |target, i|
      if target == nil
        buffer.write(" ")
      elsif 2 * target == i
        buffer.write_column(@new_columns[target], "|")
      elsif target == horiz_edge_target and i != horiz_edge - 1
        new_mapping[i] = nil unless i == 2 * target + 3
        used_horizontal = true
        buffer.write_column(@new_columns[target], "_")
      else
        if used_horizontal and i < horiz_edge
          new_mapping[i] = nil
        end
        buffer.write_column(@new_columns[target], "/")
      end
    end

    @mapping = new_mapping

    if mapping_correct?
      update_state(:padding)
    end
  end

  def mapping_correct?
    @mapping.each_with_index.all? do |target, i|
      target == nil or target == i / 2
    end
  end
end
