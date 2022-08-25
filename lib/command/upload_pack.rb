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
      STDERR.puts [:recv_want_list].inspect

      @wanted = Set.new
      pattern = /^want ([0-9a-f]+)$/

      @conn.recv_until(nil) do |line|
        oid = pattern.match(line)[1]
        @wanted.add(oid)
      end

      exit 0 if @wanted.empty?
    end

    def recv_have_list
      STDERR.puts [:recv_have_list].inspect

      @remote_has = Set.new
      pattern     = /^have ([0-9a-f]+)$/

      @conn.recv_until("done") do |line|
        if line == nil
          send_ack_message
        else
          oid = pattern.match(line)[1]
          next unless repo.database.has?(oid)
          send_ack_message(oid)
          @remote_has.add(oid)
        end
      end

      send_ack_message
    end

    def send_ack_message(oid = nil)
      message = oid ? "ACK #{ oid }" : "NAK"
      @conn.send_packet(message) if @remote_has.empty?
    end

    def send_objects
      revs = @wanted + @remote_has.map { |oid| "^#{ oid }" }
      send_packed_objects(revs)
    end

  end
end
