require_relative "./base"
require_relative "../revision"

module Command
  class Branch < Base

    def define_options
      @parser.on("-v", "--verbose") { @options[:verbose] = true }

      @parser.on("-d", "--delete") { @options[:delete] = true }
      @parser.on("-f", "--force")  { @options[:force]  = true }

      @parser.on "-D" do
        @options[:delete] = @options[:force] = true
      end
    end

    def run
      if @options[:delete]
        delete_branches
      elsif @args.empty?
        list_branches
      else
        create_branch
      end

      exit 0
    end

    private

    def list_branches
      current   = repo.refs.current_ref
      branches  = repo.refs.list_branches.sort_by(&:path)
      max_width = branches.map { |b| b.short_name.size }.max

      setup_pager

      branches.each do |ref|
        info = format_ref(ref, current)
        info.concat(extended_branch_info(ref, max_width))
        puts info
      end
    end

    def format_ref(ref, current)
      if ref == current
        "* #{ fmt :green, ref.short_name }"
      else
        "  #{ ref.short_name }"
      end
    end

    def extended_branch_info(ref, max_width)
      return "" unless @options[:verbose]

      commit = repo.database.load(ref.read_oid)
      short  = repo.database.short_oid(commit.oid)
      space  = " " * (max_width - ref.short_name.size)

      "#{ space } #{ short } #{ commit.title_line }"
    end

    def create_branch
      branch_name = @args[0]
      start_point = @args[1]

      if start_point
        revision  = Revision.new(repo, start_point)
        start_oid = revision.resolve(Revision::COMMIT)
      else
        start_oid = repo.refs.read_head
      end

      repo.refs.create_branch(branch_name, start_oid)

    rescue Refs::InvalidBranch => error
      @stderr.puts "fatal: #{ error.message }"
      exit 128

    rescue Revision::InvalidObject => error
      revision.errors.each do |err|
        @stderr.puts "error: #{ err.message }"
        err.hint.each { |line| @stderr.puts "hint: #{ line }" }
      end
      @stderr.puts "fatal: #{ error.message }"
      exit 128
    end

    def delete_branches
      @args.each { |branch_name| delete_branch(branch_name) }
    end

    def delete_branch(branch_name)
      return unless @options[:force]

      oid   = repo.refs.delete_branch(branch_name)
      short = repo.database.short_oid(oid)

      puts "Deleted branch #{ branch_name } (was #{ short })."

    rescue Refs::InvalidBranch => error
      @stderr.puts "error: #{ error }"
      exit 1
    end

  end
end
