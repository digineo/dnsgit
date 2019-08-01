require "minitest/autorun"
require "test_helper"

require "pathname"
require "tmpdir"
Bundler.require :sqlite

describe Backend::SQLite do
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
      "onupdate.sh"           => "",
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

  def with_db
    SQLite3::Database.new(@db_path.to_s, readonly: true) do |db|
      yield db
    end
  end

  before do
    prepare!
  end

  after do
    if failures.length > 0
      FileUtils.cp @db_path, "/tmp/" if @db_path.exist?
      puts @push_output
    end

    @work.rmtree if @work.exist?
  end

  it "creates DB file" do
    assert @db_path.exist?
  end

  it "creates zones" do
    have = {}
    with_db do |db|
      db.execute("select name, dnsgit_zone_hash from domains") do |row|
        name, checksum = row
        have[name] = checksum
      end
    end

    assert have.key?("example.com")
    assert have.key?("example.org")
    # If this test fails on or after 2125-01-01: congratulations, you're
    # looking at centennial code. Do you still use DNS in the future?
    assert_equal have["example.com"], "e7dd4dcfdcf0a320d0297d388e8e00d75b918038"
    assert_equal have["example.org"], "4ec2a3af6beb3eb11ebad8ba88816f1c1a636058"
  end

  def fetch_records(domain)
    records = Hash.new {|h,k| h[k] = [] }

    with_db do |db|
      q = <<~SQL.freeze
        select  records.name
              , records.type
              , records.content
              , records.ttl
              , records.prio
        from records
        inner join domains on domains.id = records.domain_id
        where records.disabled = 0
          and domains.name = '#{domain}'
      SQL
      db.execute(q) do |row|
        name, type, content, ttl, prio = row
        records[type] << { name: name, content: content, ttl: ttl, prio: prio }
      end
    end

    records
  end


  it "example.com zone is correct" do
    have = fetch_records("example.com")
    assert_equal [{
      name:     "example.com",
      ttl:      3600,
      prio:     0,
      content:  [
        "ns1.example.com",
        "webmaster.example.com",
        2124123101,
        24 * 3600,      # refresh
        3 * 3600,       # retry
        7 * 24 * 3600,  # expire
        12 * 3600,      # min ttl
      ].join(" "),
    }], have.fetch("SOA")

    {
      "A"     => [{ name: "example.com",     content: "192.168.1.1",          ttl: nil,  prio: 0 },
                  { name: "a.example.com",   content: "192.168.1.2",          ttl: 3600, prio: 0 }],
      "AAAA"  => [{ name: "example.com",     content: "2001:4860:4860::8888", ttl: nil,  prio: 0 }],
      "CNAME" => [{ name: "www.example.com", content: "example.com",          ttl: nil,  prio: 0 }],
      "MX"    => [{ name: "example.com",     content: "mx1",                  ttl: nil,  prio: 10 }],
      "NS"    => [{ name: "example.com",     content: "ns1.example.com",      ttl: nil,  prio: 0 }]
    }.each do |rtype, records|
      assert_equal records, have[rtype], "RRTYPE #{rtype} mismatch"
    end
  end

  # it "example.org zone is correct" do
  #   Dir.chdir @work.join("pdns") do
  #     zf = Zonefile.from_file "zones/example.org"

  #     zf.soa.must_equal({
  #       origin:     "@",
  #       primary:    "ns1.example.com.",
  #       email:      "webmaster.example.com.",
  #       refresh:    "1D",
  #       ttl:        "1H",
  #       minimumTTL: "600",
  #       retry:      "3H",
  #       expire:     "1W",
  #       serial:     Time.now.strftime("%Y%m%d00"),
  #     })

  #     EMPTY_RRTYPES.merge({
  #       a:      [{ name: "a",       ttl: "600", class: "IN", host: "192.168.1.3" },
  #                { name: "b",       ttl: nil,   class: "IN", host: "10.11.12.13" }],
  #       a4:     [{ name: "@",       ttl: nil,   class: "IN", host: "2001:4860:4860::6666" },
  #                { name: "b",       ttl: nil,   class: "IN", host: "2001:4860:4860::abcd" }],
  #       cname:  [{ name: "foo",     ttl: "42",  class: "IN", host: "@" },
  #                { name: "foo.bar", ttl: nil,   class: "IN", host: "@" },
  #                { name: "c",       ttl: "60",  class: "IN", host: "b" },
  #                { name: "c",       ttl: "60",  class: "IN", host: "b" }],
  #       mx:     [{ name: "@",       ttl: nil,   class: "IN", host: "mx1", pri: 10 },
  #                { name: "@",       ttl: nil,   class: "IN", host: "mx2", pri: 20 }],
  #       ns:     [{ name: "@",       ttl: nil,   class: "IN", host: "ns1.example.com." }],
  #       txt:    [{ name: "@",       ttl: "120", class: "IN", text: "a=b" }],
  #     }).each do |rtype, rrs|
  #       zf.records[rtype].must_equal rrs
  #     end
  #   end
  # end

end
