$:.unshift(File.dirname(__FILE__)+"/lib")
require 'subcommand'
require 'logger'
require 'rim/command/sync'
require 'rim/command/upload'
require 'rim/git'

include Subcommands

logger = Logger.new($stdout)
logger.level = Logger::WARN
logger.formatter = proc do |serverity, time, progname, msg|
  "#{serverity}: #{msg}\n"
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
cmdname = opt_parse()
commands[cmdname].invoke()

#manifest = RIM::Manifest::read_manifest()
#raise "not in a git repository!" unless Dir.exist?(".git")
#raise "no manifest.rim found!" if manifest.nil?
#raise "git repo has changes!" unless processor.local_changes?(".")

#RIM::Command::Update.new(processor).invoke(manifest)
#RIM::Command::Deploy.new(processor).invoke(manifest)
