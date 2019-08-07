class DebugLog
  module Logger
    private
    def logger
      @logger ||= ::DebugLog.new(self.class.name.split("::").last)
    end
  end

  ENABLED_FOR = Set.new(ENV.fetch("DNSGIT_DEBUG", "").downcase.split(",")).freeze

  COLOR_CODES = {
    DEBUG:  34,     # blue
    INFO:   [36,1], # bright cyan
    WARN:   [33,1], # bright yellow
    ERROR:  30,     # red
  }.freeze

  attr_reader :prefix, :enabled

  def initialize(prefix, force_enable=false)
    @prefix = prefix
    @enabled = force_enable ||
      ENABLED_FOR.include?("all") ||
      ENABLED_FOR.include?(prefix.downcase)
  end

  def debug(msg=nil, &block)
    log :DEBUG, msg, &block
  end

  def info(msg=nil, &block)
    log :INFO, msg, &block
  end

  def warn(msg=nil, &block)
    log :WARN, msg, &block
  end

  def error(msg=nil, &block)
    log :ERROR, msg, &block
  end

  private

  def log(level, msg=nil, &block)
    return unless enabled

    msg ||= yield if block_given?
    c = [*COLOR_CODES.fetch(level, 0)].join(";")
    $stderr.printf "\e[%sm%-5s\e[0m \e[%dm%s\e[0m\t%s\n", c, level, 35, prefix, msg.to_s
  end
end
