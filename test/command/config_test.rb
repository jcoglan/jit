require "minitest/autorun"
require "command_helper"

describe Command::Config do
  include CommandHelper

  it "returns 1 for unknown variables" do
    jit_cmd "config", "--local", "no.such"
    assert_status 1
  end

  it "returns 1 when the key is invalid" do
    jit_cmd "config", "--local", "0.0"
    assert_status 1
    assert_stderr "error: invalid key: 0.0\n"
  end

  it "returns 2 when no section is given" do
    jit_cmd "config", "--local", "no"
    assert_status 2
    assert_stderr "error: key does not contain a section: no\n"
  end

  it "returns the value of a set variable" do
    jit_cmd "config", "core.editor", "ed"

    jit_cmd "config", "--local", "Core.Editor"
    assert_status 0
    assert_stdout "ed\n"
  end

  it "returns the value of a set variable in a subsection" do
    jit_cmd "config", "remote.origin.url", "git@github.com:jcoglan.jit"

    jit_cmd "config", "--local", "Remote.origin.URL"
    assert_status 0
    assert_stdout "git@github.com:jcoglan.jit\n"
  end

  it "returns the last value of a multi-valued variable" do
    jit_cmd "config", "--add", "remote.origin.fetch", "master"
    jit_cmd "config", "--add", "remote.origin.fetch", "topic"

    jit_cmd "config", "remote.origin.fetch"
    assert_status 0
    assert_stdout "topic\n"
  end

  it "returns all the values of a multi-valued variable" do
    jit_cmd "config", "--add", "remote.origin.fetch", "master"
    jit_cmd "config", "--add", "remote.origin.fetch", "topic"

    jit_cmd "config", "--get-all", "remote.origin.fetch"
    assert_status 0

    assert_stdout <<~MSG
      master
      topic
    MSG
  end

  it "returns 5 on trying to set a multi-valued variable" do
    jit_cmd "config", "--add", "remote.origin.fetch", "master"
    jit_cmd "config", "--add", "remote.origin.fetch", "topic"

    jit_cmd "config", "remote.origin.fetch", "new-value"
    assert_status 5

    jit_cmd "config", "--get-all", "remote.origin.fetch"

    assert_stdout <<~MSG
      master
      topic
    MSG
  end

  it "replaces a multi-valued variable" do
    jit_cmd "config", "--add", "remote.origin.fetch", "master"
    jit_cmd "config", "--add", "remote.origin.fetch", "topic"
    jit_cmd "config", "--replace-all", "remote.origin.fetch", "new-value"

    jit_cmd "config", "--get-all", "remote.origin.fetch"
    assert_status 0
    assert_stdout "new-value\n"
  end
end
