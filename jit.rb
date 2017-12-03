require "fileutils"
require "pathname"

require_relative "./author"
require_relative "./database"
require_relative "./entry"
require_relative "./workspace"

command = ARGV.shift

case command
when "init"
  path = ARGV.fetch(0, Dir.getwd)

  root_path = Pathname.new(File.expand_path(path))
  git_path  = root_path.join(".git")

  ["objects", "refs"].each do |dir|
    begin
      FileUtils.mkdir_p(git_path.join(dir))
    rescue Errno::EACCES => error
      $stderr.puts "fatal: #{ error.message }"
      exit 1
    end
  end

  puts "Initialized empty Jit repository in #{ git_path }"
  exit 0

when "commit"
  root_path = Pathname.new(Dir.getwd)
  git_path  = root_path.join(".git")
  db_path   = git_path.join("objects")

  workspace = Workspace.new(root_path)
  database  = Database.new(db_path)

  entries = workspace.list_files.map do |path|
    data = workspace.read_file(path)
    blob = Blob.new(data)

    database.store(blob)

    Entry.new(path, blob.oid)
  end

  tree = Tree.new(entries)
  database.store(tree)

  name    = ENV.fetch("GIT_AUTHOR_NAME")
  email   = ENV.fetch("GIT_AUTHOR_EMAIL")
  time    = Time.now
  author  = Author.new(name, email, time)
  message = $stdin.read

  commit = Commit.new(tree.oid, author, message)
  database.store(commit)

  File.open(git_path.join("HEAD"), File::WRONLY | File::CREAT) do |file|
    file.puts(commit.oid)
  end

  puts "[(root-commit) #{ commit.oid }] #{ message.lines.first }"
  exit 0

else
  $stderr.puts "jit: '#{ command }' is not a jit command."
  exit 1
end
