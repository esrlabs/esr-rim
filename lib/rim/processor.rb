require 'fileutils'
require 'pathname'
require 'rim/git'
require 'rim/rim_exception'
require 'rake'

module RIM

class Processor

MaxThreads = 10

def initialize(workspace_root, logger)
  @ws_root = workspace_root
  while !File.directory?(File.join(@ws_root, ".git"))
    parent = File.expand_path("..", @ws_root)
    if parent != @ws_root
      @ws_root = parent
    else
      raise RimException.new("The current path is not part of a git repository.")
      break
    end
  end
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
    sub(/^(\w):/,'\1').
    # make sure we don't .. up in a filesystem
    gsub(/\.\.[\\\/]/,'')
end

def create_tmp_git(mod)
  git_path = module_git_path(mod)
  git_tmp_path = module_tmp_git_path(mod)
  FileUtils.mkdir_p git_tmp_path

  RIM::git_session(git_tmp_path) do |s|
    if !File.exist?(git_tmp_path + "/.git")
      s.execute("git clone #{mod.remote_url} #{git_tmp_path}")
    else
      s.execute("git fetch #{mod.remote_url}")
    end
  end

  git_tmp_path
end

def local_changes?(ws_dir, dir=ws_dir)
  stat = nil
  RIM::git_session(ws_dir) do |s|
    stat = s.status(dir)
  end
  stat.lines.all?{|l| l.ignored?}
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
