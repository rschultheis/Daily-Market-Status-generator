require 'logger'

class Log
  @@loggers = [Logger.new(STDOUT)]

  def self.level= log_level
    @@loggers.each { |logger| logger.level = log_level}
  end

  def self.log level, msg
    @@loggers.each {|logger| logger.send(level, msg)}
  end

  [:fatal, :error, :warn, :info,:debug].each do |log_method|
    define_singleton_method log_method do |msg|
      log(log_method, msg)
    end
  end
end


