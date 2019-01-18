require "minitest/autorun"
require "fileutils"
require "pathname"
require "securerandom"
require "set"

require "database"
require "index"
require "pack"
require "pack/xdelta"

describe Pack do
  blob_text_1 = SecureRandom.hex(256)
  blob_text_2 = blob_text_1 + "new content"

  describe Pack::XDelta do
    it "compresses a blob" do
      index = Pack::XDelta.create_index(blob_text_2)
      delta = index.compress(blob_text_1).join("")

      assert_equal 2, delta.bytesize
    end
  end

  def create_db(path)
    path = File.expand_path(path, __FILE__)
    FileUtils.mkdir_p(path)
    @db_paths.add(path)
    Database.new(Pathname.new(path))
  end

  tests = {
    "unpacking objects" => Pack::Unpacker,
    "indexing the pack" => Pack::Indexer
  }

  [false, true].each do |allow_ofs|
    describe "with ofs-delta = #{ allow_ofs }" do

      tests.each do |name, processor|
        describe name do

          before do
            @db_paths = Set.new
            source    = create_db("../db-source")
            target    = create_db("../db-target")

            @blobs = [blob_text_1, blob_text_2].map do |data|
              blob = Database::Blob.new(data)
              source.store(blob)
              Database::Entry.new(blob.oid, Index::REGULAR_MODE)
            end

            input, output = IO.pipe

            writer = Pack::Writer.new(output, source, :allow_ofs => allow_ofs)
            writer.write_objects(@blobs)

            stream = Pack::Stream.new(input)
            reader = Pack::Reader.new(stream)
            reader.read_header

            unpacker = processor.new(target, reader, stream, nil)
            unpacker.process_pack

            @db = create_db("../db-target")
          end

          after do
            @db_paths.each { |path| FileUtils.rm_rf(path) }
          end

          it "stores the blobs in the target database" do
            blobs = @blobs.map { |b| @db.load(b.oid) }

            assert_equal blob_text_1, blobs[0].data
            assert_equal blob_text_2, blobs[1].data
          end

          it "can load the info for each blob" do
            infos = @blobs.map { |b| @db.load_info(b.oid) }

            assert_equal Database::Raw.new("blob", 512), infos[0]
            assert_equal Database::Raw.new("blob", 523), infos[1]
          end
        end
      end
    end
  end
end
