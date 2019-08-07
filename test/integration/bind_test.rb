require "minitest/autorun"
require "test_helper"

class Backend::TestBIND < IntegrationTest
  EMPTY_RRTYPES = %i[
    a a4 dnskey ds naptr nsec nsec3 nsec3param ptr rrsig spf srv tlsa txt caa
  ].each_with_object({}) {|rtype, map|
    map[rtype] = []
  }

  def setup
    init_dnsgit! do
      @named_conf = @work.join("pdns/named.conf")
      @zones_dir  = @work.join("pdns/zones").tap(&:mkpath)

      {
        "bind" => {
          "named_conf"  => @named_conf.to_s,
          "zones_dir"   => @zones_dir.to_s,
        }
      }
    end
  end

  def teardown
    puts @raw_output if failures.length > 0
    @work.rmtree     if @work.exist?
  end

  def test_create_files
    Dir.chdir @work.join("pdns") do
      assert File.exist?("zones/example.com")
      assert File.exist?("zones/example.org")
    end
  end

  def test_execute_hooks
    assert_includes @push_output, [
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

  def test_example_com_zone
    Dir.chdir @work.join("pdns") do
      zf = Zonefile.from_file "zones/example.com"

      assert_equal({
        origin:     "@",
        primary:    "ns1.example.com.",
        email:      "webmaster.example.com.",
        refresh:    24 * 3600,
        ttl:        3600,
        minimumTTL: 12 * 3600,
        retry:      3 * 3600,
        expire:     7 * 24 * 3600,
        serial:     "2124123101",
      }, zf.soa)

      EMPTY_RRTYPES.merge({
        a:      [{ name: "@",   ttl: nil,  class: "IN", host: "192.168.1.1" },
                 { name: "a",   ttl: 3600, class: "IN", host: "192.168.1.2" }],
        a4:     [{ name: "@",   ttl: nil,  class: "IN", host: "2001:4860:4860::8888" }],
        cname:  [{ name: "www", ttl: nil,  class: "IN", host: "@" }],
        mx:     [{ name: "@",   ttl: nil,  class: "IN", host: "mx1", pri: 10 }],
        ns:     [{ name: "@",   ttl: nil,  class: "IN", host: "ns1.example.com." }],
      }).each do |rtype, rrs|
        assert_equal rrs, zf.records[rtype]
      end
    end
  end

  def test_example_org_zone
    Dir.chdir @work.join("pdns") do
      zf = Zonefile.from_file "zones/example.org"

      assert_equal({
        origin:     "@",
        primary:    "ns1.example.com.",
        email:      "webmaster.example.com.",
        refresh:    24 * 3600,
        ttl:        3600,
        minimumTTL: 600,
        retry:      3 * 3600,
        expire:     7 * 24 * 3600,
        serial:     "2124123101",
      }, zf.soa)

      EMPTY_RRTYPES.merge({
        a:      [{ name: "a",       ttl: 600, class: "IN", host: "192.168.1.3" },
                 { name: "b",       ttl: nil, class: "IN", host: "10.11.12.13" }],
        a4:     [{ name: "@",       ttl: nil, class: "IN", host: "2001:4860:4860::6666" },
                 { name: "b",       ttl: nil, class: "IN", host: "2001:4860:4860::abcd" }],
        cname:  [{ name: "foo",     ttl: 42,  class: "IN", host: "@" },
                 { name: "foo.bar", ttl: nil, class: "IN", host: "@" },
                 { name: "c",       ttl: 60,  class: "IN", host: "b" },
                 { name: "c",       ttl: 60,  class: "IN", host: "b" }],
        mx:     [{ name: "@",       ttl: nil, class: "IN", host: "mx1", pri: 10 },
                 { name: "@",       ttl: nil, class: "IN", host: "mx2", pri: 20 }],
        ns:     [{ name: "@",       ttl: nil, class: "IN", host: "ns1.example.com." }],
        txt:    [{ name: "@",       ttl: 120, class: "IN", text: "a=b" }],
      }).each do |rtype, rrs|
        assert_equal rrs, zf.records[rtype]
      end
    end
  end
end
