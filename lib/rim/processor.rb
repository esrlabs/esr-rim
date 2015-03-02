require 'fileutils'
require 'pathname'
require 'rim/git'
require 'rake'

module RIM

class Processor

MaxThreads = 10

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
  remote_url.sub(/^\w+:\/\//,'').gsub(/\.\.[\\\/]/,'')
end

def create_tmp_git(mod)
  git_path = module_git_path(mod)
  git_tmp_path = module_tmp_git_path(mod)
  FileUtils.mkdir_p git_tmp_path

  RIM::git_session(:git_dir => git_tmp_path) do |s|
    if !File.exist?(git_tmp_path+"/.git")
      s.execute("git clone #{mod.remote_url} #{git_tmp_path}")
    else
      s.execute("git fetch #{mod.remote_url}")
    end
  end

  git_tmp_path
end

def checkout_branch(git_dir, branch)
  RIM::git_session(:git_dir => git_dir) do |s|
    s.execute("git checkout -f #{branch}")
  end
end

def commit_working_copy(git_dir, working_copy_path, ignores = [])
  RIM::git_session(:work_dir => working_copy_path, :git_dir => git_dir) do |s|
    FileUtils.cp(FileList[working_copy_path].exclude(ignores.concat([".riminfo"])), git_dir)
    # do we need to commit something?
    stat = s.status(git_path)
    if stat.lines.any?
      s.execute("git commit #{git_path} -m \"#{msg}\"")
    end
  end
end

def local_changes?(ws_dir, dir=ws_dir)
  stat = nil
  RIM::git_session(:work_dir => ws_dir) do |s|
    stat = s.status(dir)
  end
  stat.lines.all?{|l| l.ignored?}
end

def each_module_parallel(task_desc, modules)
  if !modules.empty?
    @logger.debug "starting \"#{task_desc}\" for #{modules.size} modules\r"
    threads = []
    i = 0
    done = 0
    while i == 0 || !threads.empty?
      while threads.size < MaxThreads && i < modules.size
        threads << Thread.new(i) do |i|
          yield(modules[i], i)
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
  end
end

end

end
