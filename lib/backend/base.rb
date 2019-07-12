module Backend
  class Base
    attr_reader :base_dir, :src_template_dir, :src_zones_files
    attr_reader :config, :soa, :zones_changed

    def initialize(base_dir, config)
      @debug = ENV.fetch("DNSGIT_DEBUG", "").split(",").include?(self.class.name.split("::")[-1])

      @base_dir         = base_dir
      src               = base_dir.join("tmp/cache")
      @src_template_dir = src.join("templates")
      @src_zones_files  = Pathname.glob(src.join("zones/**/*.rb")).sort

      @config = config
      @soa    = {
        origin:     "@",
        ttl:        "86400",
        primary:    "example.com.",
        email:      "hostmaster@example.com",
        refresh:    "8H",
        retry:      "2H",
        expire:     "1W",
        minimumTTL: "11h"
      }.merge config.fetch(:soa)

      # Rewrite email address
      @soa[:email].sub!("@", ".") if @soa[:email].include?("@")
      @soa[:email] << "."         if @soa[:email][-1] != "."

      @zones_changed = []

    end

    def mark_changed(domain, reason)
      puts "#{domain} has been #{reason}"
      @zones_changed << domain
    end

    def deploy
      raise NotImplementedError, "must be implemented in subclass"
    end

    private

    # Prints a debug message. Use the block form, to avoid unnecessary
    # computation when debugging is not enabled:
    #
    #     D { "result: #{some_expensive_calculation}" }
    #     # instead of
    #     D "result: #{some_expensive_calculation}"
    #
    # Debugging is disabled by default. It can be enabled by setting
    # an environment variable to a comma-separated list of base class
    # names (e.g. DNSGIT_DEBUG=SQLite)
    def D(msg=nil)
      return unless @debug
      msg ||= yield if block_given?
      $stderr.printf "[DEBUG] %p\n", msg
    end
  end
end
