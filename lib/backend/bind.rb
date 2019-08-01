module Backend
  class BIND < Base
    attr_reader :dst_named_conf, :dst_zones_dir

    def initialize(*)
      super
      @tmp            = base_dir.join "tmp/generated"
      @tmp_named_conf = @tmp.join "named.conf"
      @tmp_zones_dir  = @tmp.join "zones"

      @dst_named_conf = Pathname.new config.fetch(:bind).fetch(:named_conf)
      @dst_zones_dir  = Pathname.new config.fetch(:bind).fetch(:zones_dir)
    end

    def deploy
      generate!

      D { "remove zones directory" }
      dst_zones_dir.rmtree

      D { "copy generated files" }
      FileUtils.copy       @tmp_named_conf, dst_named_conf
      FileUtils.copy_entry @tmp_zones_dir,  dst_zones_dir
    end

    private

    # Generate all zones
    def generate!
      # we don't want dead zone definitions
      @tmp.rmtree if @tmp.exist?
      @tmp.mkpath

      @tmp_named_conf.open("w") do |f|
        src_zones_files.each do |file|
          domain = file.basename.sub_ext("").to_s
          D { "generating zone #{domain}" }
          generate_zone(file, domain)

          f.puts %Q<zone "#{domain}" IN { type master; file "#{dst_zones_dir}/#{domain}"; };>
        end
      end
    end

    # Generate single zone
    def generate_zone(file, domain)
      zone = Zone.new(domain, src_template_dir.to_s, soa)
      zone.send :eval_file, file.to_s
      new_zonefile = zone.zonefile

      # path to the deployed version
      old_file = dst_zones_dir.join(domain)

      if old_file.exist?
        D { "found an already deployed version" }
        # parse the deployed version
        old_output   = old_file.read
        old_zonefile = Zonefile.new(old_output)
        new_zonefile.soa[:serial] = old_zonefile.soa[:serial]

        # content of the new version
        new_output = new_zonefile.output

        # has anything changed?
        if new_output != old_output
          D { "generating new serial" }
          mark_changed(domain, :updated)
          # increment serial
          new_zonefile.new_serial
          new_output = new_zonefile.output
        else
          D { "nothing has changed" }
        end
      else
        D { "zone has not existed before" }
        mark_changed(domain, :created)
        new_zonefile.new_serial
        new_output = new_zonefile.output
      end

      D { "writing new zonefile" }
      output_file_path = @tmp_zones_dir.join(domain)
      output_file_path.dirname.mkpath
      output_file_path.open("w") {|f| f.write new_output }
    end
  end
end
