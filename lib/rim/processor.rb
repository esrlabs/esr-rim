require 'fileutils'
require 'pathname'
require 'rim/file_helper'
require 'rim/git'
require 'rim/rim_exception'
require 'rake'
require 'pathname'
require 'uri'

module RIM

class Processor

MaxThreads = 10
GerritServer = "ssh://gerrit/"

def initialize(workspace_root, logger)
  @ws_root = workspace_root
  @logger = logger
end

def module_git_path(remote_path)
  # remote url without protocol specifier
  # this way the local path should be unique
  File.join(@ws_root, ".rim", remote_path)
end

def module_tmp_git_path(remote_path)
  # remote url without protocol specifier
  # this way the local path should be unique
  File.join(@ws_root, ".rim", ".tmp", remote_path)
end

def remote_path(remote_url)
  remote_url.
    # protocol specifier, e.g. ssh://
    sub(/^\w+:\/\//,'').
    # windows drive letter 
    sub(/^\w+:/,'\1').
    # make sure we don't .. up in a filesystem
    gsub(/\.\.[\\\/]/,'')
end

def get_relative_path(path)
  FileHelper.get_relative_path(path, @ws_root)
end

def get_absolute_remote_url(remote_url)
  if remote_url.start_with?("file:")
    remote_url = remote_url.gsub(/^file:(\/\/)?/, "")
    match = remote_url.match(/^\/(\w)\|/)
    if match
      remote_url = "#{match[1]}:#{remote_url[match[0].size..-1]}"
    elsif !remote_url.start_with?(File::SEPARATOR)
      File.expand_path(remote_url, @ws_root)
    else
      remote_url
    end
  else
    URI.parse(GerritServer).merge(URI.parse(remote_url)).to_s
  end
end

def local_changes?(ws_dir, dir=ws_dir)
  stat = nil
  RIM::git_session(ws_dir) do |s|
    stat = s.status(dir)
  end
  stat.lines.all?{|l| l.ignored?}
end

def clone_or_fetch_repository(remote_url, local_path, clone_log = nil)
  FileUtils.mkdir_p local_path
  RIM::git_session(local_path) do |s|
    if !File.exist?(File.join(local_path, ".git"))
      @logger.info(clone_log) if clone_log
      FileHelper.make_empty_dir(local_path)
      s.execute("git clone #{remote_url} .")
      s.execute("git config core.ignorecase false")
    else
      s.execute("git remote set-url origin #{remote_url}") if !s.has_valid_remote_repository?()
      s.execute("git fetch")
    end
  end
  local_path
end

def commit(session, message)
  msg_file = Tempfile.new('message')
  begin
    msg_file << message
    msg_file.close
    session.execute("git add --all")
    session.execute("git commit -F #{msg_file.path}")
  ensure
    msg_file.close(true)
  end
end

def each_module_parallel(task_desc, modules)
  if !modules.empty?
    @logger.debug "starting \"#{task_desc}\" for #{modules.size} modules\r"
    threads = []
    messages = []
    i = 0
    done = 0
    while i == 0 || !threads.empty?
      while threads.size < MaxThreads && i < modules.size
        threads << Thread.new(i) do |i|
          begin
            yield(modules[i], i)
          rescue RimException => e
            messages += e.messages
          end
        end
        i += 1
      end
      sleep(0.1)
      threads = threads.select{|t|
        if t.alive?
          true
        else
          t.join
          done += 1
          @logger.debug "#{task_desc} #{done}/#{modules.size}\r"
          false
        end
      }
    end
    if !messages.empty?
      raise RimException.new(messages)
    end
  end
end

end

end
