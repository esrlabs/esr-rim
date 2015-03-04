require 'rim/processor'
require 'rim/module_info'
require 'rim/rim_info'
require 'rim/manifest/json_reader'
require 'rim/status_builder'
require 'uri'

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
  def ready?
    local_changes?(@ws_root)
  end

  def modules_from_manifest(path)
    manifest = read_manifest(path)
    manifest_remote_url = manifest.remote_url ? manifest.remote_url : "ssh://gerrit/"
    remote_url = URI.parse(manifest_remote_url)
    branch_decoration = manifest_remote_url.start_with?("ssh://gerrit/") ? "refs/for/%s" : nil
    manifest.modules.each do |mod|
      if remote_url.relative?
        remote_path = File.join(manifest.remote_url, mod.remote_path) 
      else
        remote_path = remote_url.merge(mod.remote_path).to_s
      end
      add_module_info(ModuleInfo.new(remote_path, mod.local_path, mod.target_revision, mod.ignores, branch_decoration))
    end
    true
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

end

end
