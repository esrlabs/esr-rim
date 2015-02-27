require 'rim/processor'
require 'rim/rim_info'
require 'rim/manifest/json_reader'
require 'rim/status_builder'
require 'uri'

module RIM

class CommandHelper < Processor

  include Manifest

  def initialize(workspace_root, logger)
    super(workspace_root, logger)
    @logger = logger
  end

  def modules_from_manifest(path)
    manifest = read_manifest(path)
    remote_url = URI.parse(manifest.remote_url ? manifest.remote_url : "ssh://gerrit/")
    manifest.modules.each do |mod|
      if remote_url.relative?
        remote_path = File.join(manifest.remote_url, mod.remote_path) 
      else
        remote_path = remote_url.merge(mod.remote_path).to_s
      end
      add_module_info(ModuleInfo.new(remote_path, mod.local_path, mod.target_revision, mod.ignores))
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

protected
  def add_module_info(module_info)
  end

end

end
