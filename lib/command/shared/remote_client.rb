require "open3"
require "shellwords"
require "uri"

require_relative "../../remotes/protocol"

module Command
  module RemoteClient

    REF_LINE = /^([0-9a-f]+) (.*)$/
    ZERO_OID = "0" * 40

    def start_agent(name, program, url, capabilities = [])
      argv = build_agent_command(program, url)
      input, output, _ = Open3.popen2(Shellwords.shelljoin(argv))
      @conn = Remotes::Protocol.new(name, output, input, capabilities)
    end

    def build_agent_command(program, url)
      uri = URI.parse(url)
      Shellwords.shellsplit(program) + [uri.path]
    end

    def recv_references
      @remote_refs = {}

      @conn.recv_until(nil) do |line|
        oid, ref = REF_LINE.match(line).captures
        @remote_refs[ref] = oid.downcase unless oid == ZERO_OID
      end
    end

    def report_ref_update(ref_names, error, old_oid = nil, new_oid = nil, is_ff = false)
      return show_ref_update("!", "[rejected]", ref_names, error) if error
      return if old_oid == new_oid

      if old_oid == nil
        show_ref_update("*", "[new branch]", ref_names)
      elsif new_oid == nil
        show_ref_update("-", "[deleted]", ref_names)
      else
        report_range_update(ref_names, old_oid, new_oid, is_ff)
      end
    end

    def report_range_update(ref_names, old_oid, new_oid, is_ff)
      old_oid = repo.database.short_oid(old_oid)
      new_oid = repo.database.short_oid(new_oid)

      if is_ff
        revisions = "#{ old_oid }..#{ new_oid }"
        show_ref_update(" ", revisions, ref_names)
      else
        revisions = "#{ old_oid }...#{ new_oid }"
        show_ref_update("+", revisions, ref_names, "forced update")
      end
    end

    def show_ref_update(flag, summary, ref_names, reason = nil)
      names = ref_names.compact.map { |name| repo.refs.short_name(name) }

      message = " #{ flag } #{ summary } #{ names.join(" -> ") }"
      message.concat(" (#{ reason })") if reason

      @stderr.puts message
    end

  end
end
