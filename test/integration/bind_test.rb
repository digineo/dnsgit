require "minitest/autorun"
require "test_helper"

require "pathname"
require "tmpdir"

describe Backend::BIND do
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
    @named_conf = @work.join("pdns/named.conf")
    @zones_dir  = @work.join("pdns/zones").tap(&:mkpath)

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
      "onupdate.sh"           => "",
    }.each do |src, dst|
      FileUtils.cp root.join("test/fixtures/on-client", src), @on_client.join(dst)
    end
    @on_client.join("config.yaml").open("w") do |f|
      config = {
        "bind" => {
          "named_conf"  => @named_conf.to_s,
          "zones_dir"   => @zones_dir.to_s,
        },
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

  EMPTY_RRTYPES = %i[
    a a4 dnskey ds naptr nsec nsec3 nsec3param ptr rrsig spf srv tlsa txt caa
  ].each_with_object({}) {|rtype, map|
    map[rtype] = []
  }

  before do
    prepare!
  end

  after do
    @work.rmtree if @work.exist?
  end

  it "creates files" do
    Dir.chdir @work.join("pdns") do
      _(File.exist? "zones/example.com").must_equal true
      _(File.exist? "zones/example.org").must_equal true
    end
  end

  it "executes hooks" do
    @push_output.must_include [
      "example.com has been created",
      "example.org has been created",
      "Executing 'echo 1' ...",
      "1",
      "Executing './onupdate.sh' ...",
      "processing example.com ... done",
      "processing example.org ... done",
      "Executing 'echo 2' ...",
      "2",
    ].join("\n")
  end

  it "example.com zone is correct" do
    Dir.chdir @work.join("pdns") do
      zf = Zonefile.from_file "zones/example.com"

      zf.soa.must_equal({
        origin:     "@",
        primary:    "ns1.example.com.",
        email:      "webmaster.example.com.",
        refresh:    "1D",
        ttl:        "1H",
        minimumTTL: (3600*12).to_s,
        retry:      "3H",
        expire:     "1W",
        serial:     "2124123101",
      })

      EMPTY_RRTYPES.merge({
        a:      [{ name: "@",   ttl: nil,    class: "IN", host: "192.168.1.1" },
                 { name: "a",   ttl: "3600", class: "IN", host: "192.168.1.2" }],
        a4:     [{ name: "@",   ttl: nil,    class: "IN", host: "2001:4860:4860::8888" }],
        cname:  [{ name: "www", ttl: nil,    class: "IN", host: "@" }],
        mx:     [{ name: "@",   ttl: nil,    class: "IN", host: "mx1", pri: 10 }],
        ns:     [{ name: "@",   ttl: nil,    class: "IN", host: "ns1.example.com." }],
      }).each do |rtype, rrs|
        zf.records[rtype].must_equal rrs
      end
    end
  end

  it "example.org zone is correct" do
    Dir.chdir @work.join("pdns") do
      zf = Zonefile.from_file "zones/example.org"

      zf.soa.must_equal({
        origin:     "@",
        primary:    "ns1.example.com.",
        email:      "webmaster.example.com.",
        refresh:    "1D",
        ttl:        "1H",
        minimumTTL: "600",
        retry:      "3H",
        expire:     "1W",
        serial:     "2124123101",
      })

      EMPTY_RRTYPES.merge({
        a:      [{ name: "a",       ttl: "600", class: "IN", host: "192.168.1.3" },
                 { name: "b",       ttl: nil,   class: "IN", host: "10.11.12.13" }],
        a4:     [{ name: "@",       ttl: nil,   class: "IN", host: "2001:4860:4860::6666" },
                 { name: "b",       ttl: nil,   class: "IN", host: "2001:4860:4860::abcd" }],
        cname:  [{ name: "foo",     ttl: "42",  class: "IN", host: "@" },
                 { name: "foo.bar", ttl: nil,   class: "IN", host: "@" },
                 { name: "c",       ttl: "60",  class: "IN", host: "b" },
                 { name: "c",       ttl: "60",  class: "IN", host: "b" }],
        mx:     [{ name: "@",       ttl: nil,   class: "IN", host: "mx1", pri: 10 },
                 { name: "@",       ttl: nil,   class: "IN", host: "mx2", pri: 20 }],
        ns:     [{ name: "@",       ttl: nil,   class: "IN", host: "ns1.example.com." }],
        txt:    [{ name: "@",       ttl: "120", class: "IN", text: "a=b" }],
      }).each do |rtype, rrs|
        zf.records[rtype].must_equal rrs
      end
    end
  end
end
