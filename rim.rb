$:.unshift(File.dirname(__FILE__)+"/lib")
require 'subcommand'
require 'logger'
require 'rim/command/sync'
require 'rim/command/upload'
require 'rim/command/status'
require 'rim/git'

include Subcommands

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc do |severity, time, progname, msg|
  if severity == "INFO"
    "#{msg}\n"
  else
    "#{severity}: #{msg}\n"
  end
end

RIM::GitSession.logger = logger

commands = {}
add_help_option
ObjectSpace.each_object(Class).select{|clazz| clazz < RIM::Command::Command }.each do |cmdclazz|
  name = cmdclazz.name.to_s.downcase.split("::").last
  command name do |opts|
    cmd = cmdclazz.new(opts) 
    commands[name] = cmd;
  end
end
ARGV.unshift("help") if ARGV.empty?
cmdname = opt_parse()
if cmdname
  cmd = commands[cmdname]
  cmd.logger = logger
  cmd.invoke()
end
