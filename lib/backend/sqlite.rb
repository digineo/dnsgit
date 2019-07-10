Bundler.require :sqlite

module Backend
  class SQLite < Base
    attr_reader :db

    def initialize(*)
      super
      @db = SQLite3::Database.new config.fetch(:sqlite).fetch(:db_path)
      prime_database!
    end

    def deploy
      # TODO: capture new state
      src_zones_files.each do |file|
        domain = file.basename.sub_ext("").to_s
        deploy_zone(file, domain)
      end

      # TODO:
      # 0. begin transaction
      # 1. update domains set disabled = 1
      # 2. upsert domain data (also set disabled  = 0)
      # 3. delete domains where disabled = 1
      # 4. update records set disabled = 1
      # 5. upsert record data (also set disabled  = 0)
      # 6. delete records where disabled = 1
      # 7. commit transaction
    end

    private

    def deploy_zone(file, domain)
      zone = Zone.new(domain, src_template_dir.to_s, soa)
      zone.send :eval_file, file.to_s
      zf = zone.zonefile
    end

    def prime_database!
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
  end
end
