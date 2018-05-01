require_relative "./base"

module Command
  class Log < Base

    def run
      setup_pager
      each_commit { |commit| show_commit(commit) }
      exit 0
    end

    private

    def each_commit
      oid = repo.refs.read_head

      while oid
        commit = repo.database.load(oid)
        yield commit
        oid = commit.parent
      end
    end

    def blank_line
      puts "" if defined? @blank_line
      @blank_line = true
    end

    def show_commit(commit)
      author = commit.author

      blank_line
      puts fmt(:yellow, "commit #{ commit.oid }")
      puts "Author: #{ author.name } <#{ author.email }>"
      puts "Date:   #{ author.readable_time }"
      blank_line
      commit.message.each_line { |line| puts "    #{ line }" }
    end

  end
end
