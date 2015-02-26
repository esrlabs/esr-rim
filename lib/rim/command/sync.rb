require 'rim/command/command'
require 'rim/manifest/json_reader'
require 'rim/sync_helper'
require 'rim/module_info'
require 'uri'

module RIM
module Command

class Sync < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim sync <local_module_path>+"
    opts.description = "Sync rim modules according to manifest"
  end

  def invoke()
    manifest = read_manifest()
    remote_url = URI.parse(manifest.remote_url ? manifest.remote_url : "ssh://gerrit/")
    
    module_infos = []
    manifest.modules.each do |mod|
      if remote_url.relative?
        remote_path = File.join(manifest.remote_url, mod.remote_path) 
      else
        remote_path = remote_url.merge(mod.remote_path).to_s
      end      
      module_infos.push(ModuleInfo.new(remote_path, mod.local_path, mod.target_revision, mod.ignores))
    end
    
    helper = SyncHelper.new(".", module_infos, @logger)
    if helper.ready?
      helper.sync                
    else
      @logger.error "The workspace git contains uncommitted changes."
    end
  end

end

end
end


