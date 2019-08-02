require "pathname"
require "tmpdir"
require File.expand_path("../lib/environment",  __dir__)

class IntegrationTest < Minitest::Test
  def execute(cmd, *args)
    cmd = [cmd, *args].map(&:to_s)
    out = IO.popen(cmd, "r", err: [:child, :out], &:read)
    unless $?.exitstatus == 0
      raise "command failed:\n\tcmd: #{cmd}\n\tpwd: #{Dir.getwd}\n\toutput:\n#{out}"
    end
    out
  end

  # creates a temporary working directory
  def mktemp
    tmpdir = ENV["DNSGIT_TEMP_DIR"] || (File.exist?("/dev/shm") ? "/dev/shm" : Dir.tmpdir)
    Pathname.new Dir.mktmpdir("dnsgit", tmpdir)
  end

  def init_dnsgit!
    @work      = mktemp
    @on_server = @work.join("on-server")
    @on_client = @work.join("on-client")

    # clone a copy of root dir into tmpwd/on-server
    # (cp is faster than `git clone ../ ./on-server`)
    root = Pathname.new(__dir__).join("..")
    FileUtils.cp_r root, @on_server

    # initialize copy
    Dir.chdir @on_server do
      execute "bin/init"
    end

    # clone a client copy to tmpwd/on-client
    Dir.chdir @work do
      execute "git", "clone", "on-server/data", "./on-client"
    end

    # prepare tmpwd/on-client
    @on_client.join("templates").each_child(&:delete)
    @on_client.join("zones").each_child(&:delete)
    {
      "templates/ns.rb"       => "templates/",
      "zones/example.com.rb"  => "zones/",
      "zones/example.org.rb"  => "zones/",
      "onupdate.sh"           => "",
    }.each do |src, dst|
      FileUtils.cp root.join("test/fixtures/on-client", src), @on_client.join(dst)
    end

    config = yield
    @on_client.join("config.yaml").open("w") do |f|
      cfg = {
        "execute"       => ["echo 1", "./onupdate.sh", "echo 2"],
        "soa" => {
          "primary"     => "ns1.example.com.",
          "email"       => "webmaster@example.com",
          "ttl"         => "1H",
          "refresh"     => "1D",
          "retry"       => "3H",
          "expire"      => "1W",
          "minimumTTL"  => "2D",
        }
      }.merge(config)
      f.write cfg.to_yaml
    end

    commit!
  end

  def commit!
    Dir.chdir @on_client do
      execute "git", "add", "-A"
      execute "git", "commit", "-m", "hook integration test"
      @push_output = execute("git", "push")
        .gsub(/^remote:\s?(.*?)\s*$/, '\1')
        .gsub(/\e\[\d+m/, '')
    end
  end
end
