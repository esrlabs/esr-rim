require 'rim/processor'
require 'rim/rim_exception'
require 'rim/rim_info'
require 'rim/file_helper'
require 'rim/dirty_check'

module RIM

class ModuleHelper < Processor

  def initialize(workspace_root, module_info, logger)
    super(workspace_root, logger)
    @module_info = module_info
    @remote_path = remote_path(@module_info.remote_url)
    @logger = logger
  end
  
protected
  
  # fetch module +mod+ into the .rim folder
  # works both for initial fetch and updates
  def fetch_module
    git_path = module_git_path(@remote_path)
    FileUtils.mkdir_p git_path
    RIM::git_session(git_path) do |s|
      if !File.exist?(git_path + "/config")
        s.execute("git clone --mirror #{@module_info.remote_url} #{git_path}") do |out, e|
          raise RimException.new("Remote repository '#{@module_info.remote_url}' of module '#{@module_info.local_path}' not found.") if e
        end
      else
        s.execute("git remote update")
      end
    end
    git_path
  end

  # prepare empty folder: remove all files not on the ignore list and empty folders
  def prepare_empty_folder(local_path, ignores)
    ignores = FileHelper.find_matching_files(local_path, true, ignores)
    FileHelper.find_matching_files(local_path, true, "/**/*", File::FNM_DOTMATCH).each do |f|
      if File.file?(f) && !ignores.include?(f)
        FileUtils.rm(f)
      end
    end
    FileHelper.remove_empty_dirs(local_path)
    FileUtils.mkdir_p(local_path)
  end

end

end
