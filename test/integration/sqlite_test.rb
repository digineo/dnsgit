require "minitest/autorun"
require "test_helper"

require "pathname"
require "tmpdir"

describe "hooks" do
  def execute(cmd, *args)
    cmd = [cmd, *args].map(&:to_s)
    out = IO.popen(cmd, "r", err: [:child, :out], &:read)
    unless $?.exitstatus == 0
      raise "command failed:\n\tcmd: #{cmd}\n\tpwd: #{Dir.getwd}\n\toutput:\n#{out}"
    end
    out
  end

  def prepare!
    # create a temp. working directory
    tmpdir = File.exist?("/dev/shm") ? "/dev/shm" : Dir.tmpdir
    @work = Pathname.new(Dir.mktmpdir("dnsgit", tmpdir))

    @on_server  = @work.join("on-server")
    @on_client  = @work.join("on-client")
    @db_path    = @work.join("pdns.sqlite3")

    # clone a copy of root dir into tmpwd/on-server
    root = Pathname.new(__dir__).join("../..")
    Dir.chdir @work do
      # faster than `git clone ../.. ./on-server`
      FileUtils.cp_r root, @on_server
    end

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
    }.each do |src, dst|
      FileUtils.cp root.join("test/fixtures/on-client", src), @on_client.join(dst)
    end
    @on_client.join("config.yaml").open("w") do |f|
      config = {
        "sqlite" => {
          "db_path"     => @db_path.to_s,
        },
        "soa" => {
          "primary"     => "ns1.example.com.",
          "email"       => "webmaster@example.com",
          "ttl"         => "1H",
          "refresh"     => "1D",
          "retry"       => "3H",
          "expire"      => "1W",
          "minimumTTL"  => "2D",
        }
      }
      f.write config.to_yaml
    end
    Dir.chdir @on_client do
      execute "git", "add", "-A"
      execute "git", "commit", "-m", "hook integration test"
      @push_output = execute("git", "push")
        .gsub(/^remote:\s?(.*?)\s*$/, '\1')
        .gsub(/\e\[\d+m/, '')
    end
  end

  EMPTY_RRTYPES =%i[
    a a4 dnskey ds naptr nsec nsec3 nsec3param ptr rrsig soa spf srv tlsa txt
  ].each_with_object({}) {|rtype, map|
    map[rtype] = []
  }

  before do
    prepare!
  end

  after do
    # @work.rmtree if @work.exist?
  end

  it "creates files" do
    _(@db_path.exist?).must_equal true
  end
end
