require "pathname"

class ZoneGenerator
  def self.run(basedir)
    zg = new basedir
    zg.generate
    zg.deploy
  end

  def initialize(basedir)
    basedir = Pathname.new(basedir)

    @generated    = basedir.join "tmp/generated"
    @workspace    = basedir.join "tmp/cache"
    @zones_dir    = @workspace.join "zones"
    @template_dir = @workspace.join "templates"

    @tmp_named = @generated.join "named.conf"
    @tmp_zones = @generated.join "zones"

    config = YAML.load @workspace.join("config.yaml").read
    config.deep_symbolize_keys!
    @soa = {
      origin:     "@",
      ttl:        "86400",
      primary:    "example.com.",
      email:      "hostmaster@example.com",
      refresh:    "8H",
      retry:      "2H",
      expire:     "1W",
      minimumTTL: "11h"
    }.merge(config[:soa])

    # Rewrite email address
    if (email = @soa[:email]).include?("@")
      @soa[:email] = email.sub("@", ".") << "."
    end

    @pdns_named_conf = Pathname.new config[:named_conf]
    @pdns_zones_dir = Pathname.new config[:zones_dir]
    @after_deploy = config[:execute]

    # we don't want dead zone definitions
    @generated.rmtree if @generated.exist?
    @generated.mkpath
  end

  # Generates all zones
  def generate
    @tmp_named.open("w") do |f|
      Pathname.glob(@zones_dir.join("**/*.rb")).sort.each do |file|
        domain = File.basename(file).sub(/\.rb$/, "")
        generate_zone(file, domain)

        f.puts %Q<zone "#{domain}" IN { type master; file "#{@pdns_zones_dir}/#{domain}"; };>
      end
    end
  end

  # Generates a single zone file
  def generate_zone(file, domain)
    zone = Zone.new(domain, @template_dir.to_s, @soa)
    zone.send :eval_file, file.to_s
    new_zonefile = zone.zonefile

    # path to the deployed version
    old_file = Pathname.new(@pdns_zones_dir).join(domain)

    # is there already a deployed version?
    if old_file.exist?
      # parse the deployed version
      old_output   = old_file.read
      old_zonefile = Zonefile.new(old_output)
      new_zonefile.soa[:serial] = old_zonefile.soa[:serial]

      # content of the new version
      new_output = new_zonefile.output

      # has anything changed?
      if new_output != old_output
        puts "#{domain} has been updated"
        # increment serial
        new_zonefile.new_serial
        new_output = new_zonefile.output
      end
    else
      # zone has not existed before
      puts "#{domain} has been created"
      new_zonefile.new_serial
      new_output = new_zonefile.output
    end

    # Write new zonefile
    output_file_path = @tmp_zones.join(domain)
    output_file_path.dirname.mkpath
    output_file_path.open("w") {|f| f.write new_output }
  end

  def deploy
    # Remove zones directory
    @pdns_zones_dir.rmtree

    FileUtils.copy       @tmp_named, @pdns_named_conf
    FileUtils.copy_entry @tmp_zones, @pdns_zones_dir

    if cmd = @after_deploy
      print "Executing '#{cmd}' ... "
      out = `#{cmd}`
      puts "done"

      raise out if $?.to_i != 0
    end
  end
end
