class DebugLog
  module Logger
    private
    def logger
      @logger ||= ::DebugLog.new(self.class.name.split("::").last)
    end
  end

  ENABLED_FOR = Set.new(ENV.fetch("DNSGIT_DEBUG", "").downcase.split(",")).freeze

  COLOR_CODES = {
    debug:  34, # blue
    info:   36, # cyan
    warn:   33, # yellow
    error:  30, # red
  }.freeze

  attr_reader :prefix, :enabled

  def initialize(prefix, force_enable=false)
    @prefix = prefix
    @enabled = force_enable ||
      ENABLED_FOR.include?("all") ||
      ENABLED_FOR.include?(prefix.downcase)
  end

  def debug(msg=nil, &block)
    log :debug, msg, &block
  end

  def info(msg=nil, &block)
    log :info, msg, &block
  end

  def warn(nsg=nil, &block)
    log :warn, msg, &block
  end

  def error(msg=nil, &block)
    log :error, msg, &block
  end

  private

  def log(level, msg=nil, &block)
    return unless enabled

    msg ||= yield if block_given?
    c = COLOR_CODES.fetch(level, 0)
    $stderr.printf "[%s] \e[%dm%5s\e[0m %s\n", prefix, c, level, msg.to_s
  end
end
