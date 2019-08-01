require "digest/sha1"
Bundler.require :sqlite

module Backend
  class SQLite < Base
    attr_reader :db

    def initialize(*)
      super

      @db = SQLite3::Database.new config.fetch(:sqlite).fetch(:db_path)
      db.foreign_keys = true
      prime_database!
      prepare_statements!
    end

    def close
      @prepared_statements.each do |_, stmt|
        stmt.close
      end
      @db.close
    end

    Work = Struct.new(:zonefile, :id, :need_update) do
      def checksum
        @checksum ||= Digest::SHA1.hexdigest(zonefile.output)
      end

      def resource_records
        zonefile.resource_records
      end

      def bump_serial!
        zonefile.new_serial
        @checksum = nil
      end

      def serial=(value)
        zonefile.soa[:serial] = value
        @checksum = nil
      end
    end
    private_constant :Work

    def deploy
      zones = {}

      src_zones_files.each do |file|
        domain   = file.basename.sub_ext("").to_s
        D { "build zonefile for #{domain}" }
        zonefile = build_zone_file(file, domain)

        zones[domain] = Work.new(zonefile).tap {|work|
          # will be annotated with current values in #annotate_state
          work.serial      = zonefile.soa[:serial] || 0
          work.need_update = true
        }
      end

      db.transaction do
        D { :annotate_state }
        annotate_state(zones)
        D { :update_database }
        update_database(zones)
      end
    end

    private

    UPSERT_DOMAIN_SQL = <<~SQL.freeze
      insert into domains (name, type)
        values (:name, 'MASTER')
        on conflict (name) do nothing
    SQL
    private_constant :UPSERT_DOMAIN_SQL

    UPDATE_DOMAIN_CHECKSUM_SQL = <<~SQL.freeze
      update domains
        set dnsgit_zone_hash = :checksum
        where id = :id
    SQL
    private_constant :UPDATE_DOMAIN_CHECKSUM_SQL

    DELETE_RECORD_SQL = <<~SQL.freeze
      delete from records where domain_id = :domain_id
    SQL
    private_constant :DELETE_RECORD_SQL

    INSERT_RECORD_SQL = <<~SQL.freeze
      insert into records (domain_id, name, type, content, ttl, prio, disabled)
        values (:domain_id, :name, :type, :content, :ttl, :prio, 0)
    SQL
    private_constant :INSERT_RECORD_SQL

    # retrieves the SOA record's serial number for each domain in
    # `zones` and overrides the value of a domain's zonefile.
    def annotate_state(zones)
      q = <<~SQL.freeze
        select  domains.name
              , domains.dnsgit_zone_hash
              , records.content
        from domains
        inner join records on records.domain_id = domains.id
        where records.type = 'SOA'
      SQL

      execute(q) do |row|
        domain, checksum, rrdata = row
        next unless zones.key?(domain)
        _, _, serial, _, _, _, _ = rrdata.split(/\s+/)

        D { "need_update(#{domain}) = #{zones[domain].checksum != checksum}" }
        zones[domain].serial      = serial
        zones[domain].need_update = zones[domain].checksum != checksum
      end
    end

    def update_database(zones)
      # insert or update domain names
      zones.keys.each do |domain|
        execute_prepared(:upsert_domain, "name" => domain)
      end

      D { "fetch all ids, remember extranuous records" }
      extra = []
      execute "select name, id from domains" do |row|
        domain, id = row
        if zones.key?(domain)
          zones[domain].id = id
        else
          extra << id
        end
      end

      if extra.length > 0
        D { "remove extranuous domains" }
        execute "delete from domains where id in (#{extra.join(', ')})"
      end

      D { "delete all records where update is needed" }
      zones.each do |domain, work|
        next unless work.need_update

        execute_prepared(:delete_record, {
          "domain_id" => work.id,
        })

        work.bump_serial!
        work.resource_records.each do |name, rrs|
          rrs = [rrs] if name === :soa
          upsert_domain_records(work.id, rrs, work.zonefile.origin, work.zonefile.ttl)
        end

        execute_prepared(:domain_checksum, {
          "id"        => work.id,
          "checksum"  => work.checksum,
        })
        mark_changed(domain, :updated)
      end
    end

    def upsert_domain_records(domain_id, records, origin, default_ttl)
      records.each do |rr|
        prio, content = if %w[MX SRV].include?(rr.type)
          rr.data.split(/\s+/, 2)
        else
          [0, rr.data]
        end

        name = rr.name == "@" ? origin : "#{rr.name}.#{origin}"
        content = content.split(/\s+/).map{|e| e.gsub("@", origin).chomp(".") }.join(" ")

        execute_prepared(:insert_record, {
          "domain_id" => domain_id,
          "name"      => name,
          "type"      => rr.type,
          "content"   => content,
          "ttl"       => rr.ttl || default_ttl,
          "prio"      => prio,
        })
      end
    end

    def prepare_statements!
      @prepared_statements = {
        upsert_domain:    db.prepare(UPSERT_DOMAIN_SQL),
        domain_checksum:  db.prepare(UPDATE_DOMAIN_CHECKSUM_SQL),
        delete_record:    db.prepare(DELETE_RECORD_SQL),
        insert_record:    db.prepare(INSERT_RECORD_SQL),
      }
    end

    def execute_prepared(name, *args)
      Dsql { { prep_stmt: name, args: args } }
      @prepared_statements.fetch(name).execute(*args)
    end

    def execute(query, *args, &block)
      Dsql { { query: query.gsub("\n", " ").squeeze(" "), args: args } }
      db.execute(query, *args, &block)
    end

    def build_zone_file(file, domain)
      zone = Zone.new(domain, src_template_dir.to_s, soa)
      zone.send :eval_file, file.to_s
      zone.zonefile
    end

    def prime_database!
      check_pdns_schema!    # create upstream schema
      check_helper_columns! # modify schema/custom migrations
    end

    def check_pdns_schema!
      have = Set.new
      want = Set.new %w[ domains records supermasters comments domainmetadata cryptokeys tsigkeys ]

      db.execute("select name from sqlite_master where type='table'") do |rows|
        have << row[0]
      end

      diff = want - have

      # do we have it all?
      return if diff.size == 0

      # do we have some?
      if 0 < diff.size && diff.size < want.size
        raise "unknown DB state, we have columns #{have.to_a} and want #{want.to_a}"
      end

      # should not occur
      if diff.size != want.size
        raise "bug: #{have.to_a} is not empty!?"
      end

      # db is empty, apply schema
      schema = Pathname.new(__dir__).join("schema.sql").read
      db.execute_batch(schema)
    end

    def check_helper_columns!
      # we use SHA1(zonefile) to determine changes in a zone
      have_zone_hash = db.table_info(:domains)
        .map {|info| info["name"] }
        .include?("dnsgit_zone_hash")

      unless have_zone_hash
        db.execute "alter table domains add column dnsgit_zone_hash varchar(40) default null"
      end
    end

    def Dsql
      return unless @debug
      $stderr.printf "[SQL] %p\n", yield
    end
  end
end
