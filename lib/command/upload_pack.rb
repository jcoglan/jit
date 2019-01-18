require "set"

require_relative "./base"
require_relative "./shared/remote_agent"
require_relative "./shared/send_objects"

module Command
  class UploadPack < Base

    include RemoteAgent
    include SendObjects

    CAPABILITIES = ["ofs-delta"]

    def run
      accept_client("upload-pack", CAPABILITIES)

      send_references
      recv_want_list
      recv_have_list
      send_objects

      exit 0
    end

    private

    def recv_want_list
      @wanted = recv_oids("want", nil)
      exit 0 if @wanted.empty?
    end

    def recv_have_list
      @remote_has = recv_oids("have", "done")
      @conn.send_packet("NAK")
    end

    def recv_oids(prefix, terminator)
      pattern = /^#{ prefix } ([0-9a-f]+)$/
      result  = Set.new

      @conn.recv_until(terminator) do |line|
        result.add(pattern.match(line)[1])
      end
      result
    end

    def send_objects
      revs = @wanted + @remote_has.map { |oid| "^#{ oid }" }
      send_packed_objects(revs)
    end

  end
end
