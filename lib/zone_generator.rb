class ZoneGenerator
  def initialize(basedir)
    @generated    = "#{basedir}/tmp/generated"
    @workspace    = "#{basedir}/tmp/cache"
    @zones_dir    = "#{@workspace}/zones"
    @template_dir = "#{@workspace}/templates"

    @tmp_named = "#{@generated}/named.conf"
    @tmp_zones = "#{@generated}/zones"

    @config = YAML.load_file("#{@workspace}/config.yaml")
    @config.deep_symbolize_keys!
    @soa = {
      origin: "@",
      ttl: "86400",
      primary: "example.com.",
      email: "hostmaster@example.com",
      refresh: "8H",
      retry: "2H",
      expire: "1W",
      minimumTTL: "11h"
    }.merge(@config[:soa])

    # Rewrite email address
    if (email = @soa[:email]).include?("@")
      @soa[:email] = email.sub("@",".") << "."
    end

    FileUtils.rm_rf   @generated # Tote Zonen-Definitionen brauchen wir nicht.
    FileUtils.mkdir_p @generated
  end

  # Generates all zones
  def generate
    File.open(@tmp_named,"w") do |f|
      Dir.glob("#{@zones_dir}/**/*.rb").sort.each do |file|
        domain = File.basename(file).sub(/\.rb$/,"")
        generate_zone(file, domain)

        f.puts %Q<zone "#{domain}" IN { type master; file "#{@config[:zones_dir]}/#{domain}"; };>
      end
    end
  end

  # Generates a single zone file
  def generate_zone(file, domain)
    zone = Zone.new(domain, @template_dir, @soa)
    zone.send :eval_file, file
    new_zonefile = zone.zonefile

    # path to the deployed version
    old_file = "#{@config[:zones_dir]}/#{domain}"

    # is there already a deployed version?
    if File.exists?(old_file)
      # parse the deployed version
      old_output   = File.read(old_file)
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
    output_file_path = "#{@tmp_zones}/#{domain}"
    FileUtils.mkdir_p File.dirname(output_file_path)
    File.open(output_file_path, "w"){|f| f.write new_output }
  end

  def deploy
    # Remove zones directory
    FileUtils.rm_rf @config[:zones_dir]

    FileUtils.copy       @tmp_named, @config[:named_conf]
    FileUtils.copy_entry @tmp_zones, @config[:zones_dir]

    cmd = @config[:execute]
    print "Executing '#{cmd}' ... "
    out = `#{cmd}`
    puts "done"

    raise out if $?.to_i != 0
  end
end
