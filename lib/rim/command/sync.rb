require 'rim/command/command'
require 'rim/manifest/json_reader'
require 'rim/sync_helper'
require 'rim/module_info'

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
    
    module_infos = []
    manifest.modules.each do |mod|
      module_infos.push(ModuleInfo.new(File.join(mod.remote.fetch_url, mod.remote_path), mod.local_path, mod.revision))
    end
    
    helper = SyncHelper.new(".", module_infos)
    if helper.ready?
      helper.sync                
    else
      puts "workspace not ready!"
    end
  end

end

end
end


