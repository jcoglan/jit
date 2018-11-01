require "set"

require_relative "./base"
require_relative "./shared/fast_forward"
require_relative "./shared/receive_objects"
require_relative "./shared/remote_client"
require_relative "../remotes"
require_relative "../rev_list"

module Command
  class Fetch < Base

    include FastForward
    include ReceiveObjects
    include RemoteClient

    UPLOAD_PACK = "git-upload-pack"

    def define_options
      @parser.on("-f", "--force") { @options[:force] = true }

      @parser.on "--upload-pack=<upload-pack>" do |uploader|
        @options[:uploader] = uploader
      end
    end

    def run
      configure
      start_agent("fetch", @uploader, @fetch_url)

      recv_references
      send_want_list
      send_have_list
      recv_objects
      update_remote_refs

      exit (@errors.empty? ? 0 : 1)
    end

    private

    def configure
      name   = @args.fetch(0, Remotes::DEFAULT_REMOTE)
      remote = repo.remotes.get(name)

      @fetch_url   = remote&.fetch_url || @args[0]
      @uploader    = @options[:uploader] || remote&.uploader || UPLOAD_PACK
      @fetch_specs = (@args.size > 1) ? @args.drop(1) : remote&.fetch_specs
    end

    def send_want_list
      @targets = Remotes::Refspec.expand(@fetch_specs, @remote_refs.keys)
      wanted   = Set.new

      @local_refs = {}

      @targets.each do |target, (source, _)|
        local_oid  = repo.refs.read_ref(target)
        remote_oid = @remote_refs[source]

        next if local_oid == remote_oid

        @local_refs[target] = local_oid
        wanted.add(remote_oid)
      end

      wanted.each { |oid| @conn.send_packet("want #{ oid }") }
      @conn.send_packet(nil)

      exit 0 if wanted.empty?
    end

    def send_have_list
      options  = { :all => true, :missing => true }
      rev_list = ::RevList.new(repo, [], options)

      rev_list.each { |commit| @conn.send_packet("have #{ commit.oid }") }
      @conn.send_packet("done")

      @conn.recv_until(Pack::SIGNATURE) {}
    end

    def recv_objects
      recv_packed_objects(Pack::SIGNATURE)
    end

    def update_remote_refs
      @stderr.puts "From #{ @fetch_url }"

      @errors = {}
      @local_refs.each { |target, oid| attempt_ref_update(target, oid) }
    end

    def attempt_ref_update(target, old_oid)
      source, forced = @targets[target]

      new_oid   = @remote_refs[source]
      ref_names = [source, target]
      ff_error  = fast_forward_error(old_oid, new_oid)

      if @options[:force] or forced or ff_error == nil
        repo.refs.update_ref(target, new_oid)
      else
        error = @errors[target] = ff_error
      end

      report_ref_update(ref_names, error, old_oid, new_oid, ff_error == nil)
    end

  end
end
