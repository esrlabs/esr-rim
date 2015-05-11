require 'logger'

module RIM

class FileLogger < Logger

  def initialize(name, file)
    super(name)
    FileUtils.mkdir_p(File.dirname(file))
    @file_logger = Logger.new(file)
    @file_logger.level = Logger::DEBUG
  end

  def add(severity, message = nil, progname = nil, &block)
    @file_logger.add(severity, message, progname)
    super(severity, message, progname)    
  end

end

end
