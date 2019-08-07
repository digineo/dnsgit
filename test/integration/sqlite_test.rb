require "minitest/autorun"
require "test_helper"
Bundler.require :sqlite

class Backend::TestSQLite < IntegrationTest
  def with_db
    SQLite3::Database.new(@db_path.to_s, readonly: true) do |db|
      yield db
    end
  end

  def setup
    init_dnsgit! do
      @db_path = @work.join("pdns.sqlite3")
      { "sqlite" => { "db_path" => @db_path.to_s } }
    end
  end

  def teardown
    keep_db = ENV["DNSGIT_KEEP_DB"] == "1" && @db_path.exist?

    FileUtils.cp @db_path, "/tmp/"  if keep_db
    puts @raw_output                if failures.length > 0
    @work.rmtree                    if @work.exist?
  end

  def test_create_db_file
    assert @db_path.exist?
  end

  def test_execute_hooks
    assert_includes @push_output, [
      "example.com has been updated",
      "example.org has been updated",
      "Executing 'echo 1' ...",
      "1",
      "Executing './onupdate.sh' ...",
      "processing example.com ... done",
      "processing example.org ... done",
      "Executing 'echo 2' ...",
      "2",
    ].join("\n")
  end

  def test_create_zones
    have = {}
    with_db do |db|
      db.execute("select name, dnsgit_zone_hash from domains") do |(name, checksum)|
        have[name] = checksum
      end
    end

    assert have.key?("example.com")
    assert have.key?("example.org")
    # If this test fails on or after 2125-01-01: congratulations, you're
    # looking at centennial code. Do you still use DNS in the future?
    assert_equal "fdaa632ef880afde15d677a6e9cf6ed391b9593e", have["example.com"]
    assert_equal "fc9982b93739c4ff3b45becb56b37c220422e344", have["example.org"]
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
      db.execute(q) do |(name, type, content, ttl, prio)|
        records[type] << { name: name, content: content, ttl: ttl, prio: prio }
      end
    end

    records
  end

  def test_example_com_zone
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
      ].join("\t"),
    }], have.fetch("SOA"), "RRTYPE SOA mismatch"

    {
      "A"     => [{ name: "example.com",     content: "192.168.1.1",          ttl: nil,  prio: 0 },
                  { name: "a.example.com",   content: "192.168.1.2",          ttl: 3600, prio: 0 }],
      "AAAA"  => [{ name: "example.com",     content: "2001:4860:4860::8888", ttl: nil,  prio: 0 }],
      "CNAME" => [{ name: "www.example.com", content: "example.com",          ttl: nil,  prio: 0 }],
      "MX"    => [{ name: "example.com",     content: "mx1.example.com",      ttl: nil,  prio: 10 }],
      "NS"    => [{ name: "example.com",     content: "ns1.example.com",      ttl: nil,  prio: 0 }]
    }.each do |rtype, records|
      assert_equal records, have[rtype], "RRTYPE #{rtype} mismatch"
    end
  end

  def test_example_org_zone
    have = fetch_records("example.org")

    assert_equal [{
      name:     "example.org",
      ttl:      3600,
      prio:     0,
      content:  [
        "ns1.example.com",
        "webmaster.example.com",
        2124123101,
        24 * 3600,      # refresh
        3 * 3600,       # retry
        7 * 24 * 3600,  # expire
        600,            # min ttl
      ].join("\t"),
    }], have.fetch("SOA"), "RRTYPE SOA mismatch"

    {
      "A"     => [{ name: "a.example.org",       content: "192.168.1.3",          ttl: 600, prio: 0 },
                  { name: "b.example.org",       content: "10.11.12.13",          ttl: nil, prio: 0 }],
      "AAAA"  => [{ name: "example.org",         content: "2001:4860:4860::6666", ttl: nil, prio: 0 },
                  { name: "b.example.org",       content: "2001:4860:4860::abcd", ttl: nil, prio: 0 }],
      "CNAME" => [{ name: "foo.example.org",     content: "a.example.org",        ttl: 42,  prio: 0 },
                  { name: "foo.bar.example.org", content: "a.example.org",        ttl: nil, prio: 0 },
                  { name: "c.example.org",       content: "b.example.org",        ttl: 60,  prio: 0 }],
      "MX"    => [{ name: "example.org",         content: "mx1.example.org",      ttl: nil, prio: 10 },
                  { name: "example.org",         content: "mx2.example.org",      ttl: nil, prio: 20 }],
      "NS"    => [{ name: "example.org",         content: "ns1.example.com",      ttl: nil, prio: 0 }],
      "TXT"   => [{ name: "a.example.org",       content: "a=b",                  ttl: 120, prio: 0 }],
    }.each do |rtype, records|
      assert_equal records, have[rtype], "RRTYPE #{rtype} mismatch"
    end
  end

  def test_update_zone_affects_only_updated_zone
    hashes = {}
    with_db do |db|
      db.execute("select name, dnsgit_zone_hash from domains") do |(domain, checksum)|
        hashes[domain] = { old: checksum, new: nil }
      end
    end

    @on_client.join("zones/example.com.rb").open("a") do |z|
      z.puts "", "txt 'foo'"
    end
    commit!

    with_db do |db|
      db.execute("select name, dnsgit_zone_hash from domains") do |(domain, checksum)|
        hashes[domain][:new] = checksum
      end
    end

    zone = hashes.fetch("example.org")
    refute_includes @push_output, "example.org has been updated"
    assert_equal zone[:old], zone[:new], "example.org zone changed (it ought not to)"

    zone = hashes.fetch("example.com")
    assert_includes @push_output, "example.com has been updated"
    refute_equal zone[:old], zone[:new], "example.com zone did not change (it ought to)"
  end
end
