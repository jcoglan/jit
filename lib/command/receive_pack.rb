require_relative "./base"
require_relative "./shared/receive_objects"
require_relative "./shared/remote_agent"

module Command
  class ReceivePack < Base

    include ReceiveObjects
    include RemoteAgent

    CAPABILITIES = ["no-thin", "report-status", "delete-refs"]

    def run
      accept_client("receive-pack", CAPABILITIES)

      send_references
      recv_update_requests
      recv_objects
      update_refs

      exit 0
    end

    private

    def recv_update_requests
      @requests = {}

      @conn.recv_until(nil) do |line|
        old_oid, new_oid, ref = line.split(/ +/)
        @requests[ref] = [old_oid, new_oid].map { |oid| zero_to_nil(oid) }
      end
    end

    def zero_to_nil(oid)
      oid == ZERO_OID ? nil : oid
    end

    def recv_objects
      @unpack_error = nil
      recv_packed_objects if @requests.values.any?(&:last)
      report_status("unpack ok")
    rescue => error
      @unpack_error = error
      report_status("unpack #{ error.message }")
    end

    def update_refs
      @requests.each { |ref, (old, new)| update_ref(ref, old, new) }
      report_status(nil)
    end

    def update_ref(ref, old_oid, new_oid)
      return report_status("ng #{ ref } unpacker error") if @unpack_error

      repo.refs.compare_and_swap(ref, old_oid, new_oid)
      report_status("ok #{ ref }")
    rescue => error
      report_status("ng #{ ref } #{ error.message }")
    end

    def report_status(line)
      @conn.send_packet(line) if @conn.capable?("report-status")
    end

  end
end
