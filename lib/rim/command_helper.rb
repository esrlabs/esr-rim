require 'rim/file_helper'
require 'rim/processor'
require 'rim/module_info'
require 'rim/rim_info'
require 'rim/manifest/json_reader'
require 'rim/status_builder'

module RIM

class CommandHelper < Processor

  include Manifest

  def initialize(workspace_root, logger, module_infos = nil)
    super(workspace_root, logger)
    @logger = logger
    if module_infos
      module_infos.each do |m|
        add_module_info(m)
      end
    end
  end

  # check whether workspace is not touched
  def check_ready
    raise RimException.new("The workspace git contains uncommitted changes.") if !local_changes?(@ws_root)
  end
  
  def check_arguments
    raise RimException.new("Unexpected command line arguments.") if !ARGV.empty?
  end

  def create_module_info(remote_url, local_path, target_revision, ignores)
    ModuleInfo.new(remote_url, get_relative_path(local_path), target_revision, ignores, get_remote_branch_format(remote_url))
  end

  def modules_from_manifest(path)
    manifest = read_manifest(path)
    manifest.modules.each do |mod|
      add_module_info(create_module_info(mod.remote_path, mod.local_path, mod.target_revision, mod.ignores))
    end
    true
  end
  
  def module_from_path(path, opts = {})
    path = File.expand_path(path)
    if File.file?(File.join(path, RimInfo::InfoFileName))
      rim_info = RimInfo.from_dir(path)
      add_module_info(create_module_info(opts.has_key?(:remote_url) ? opts[:remote_url] : rim_info.remote_url, \
          path, opts.has_key?(:target_revision) ? opts[:target_revision] : rim_info.target_revision, \
          opts.has_key?(:ignores) ? opts[:ignores] : rim_info.ignores))
    else
      raise RimException.new("No module info found in '#{path}'.") 
    end
  end
  
  def modules_from_workspace()
    if File.directory?(File.join(@ws_root, ".rim"))
      status = StatusBuilder.new.fs_status(@ws_root)
      status.modules.each do |mod|
        rim_info = mod.rim_info
        add_module_info(ModuleInfo.new(rim_info.remote_url, mod.dir, rim_info.upstream, rim_info.ignores))
      end
      true
    end
  end

  def add_module_info(module_info)
  end

  def get_remote_branch_format(remote_url)
    get_absolute_remote_url(remote_url).start_with?(GerritServer) ? "refs/for/%s" : nil
  end

end

end
