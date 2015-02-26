require 'rim/command/command'
require 'rim/manifest/helper'
require 'rim/manifest/json_reader'
require 'rim/status_builder'
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
    opts.on("-m[MANIFEST]", "--manifest=[MANIFEST]", String, "Read information from manifest") do |manifest|
      @manifest = manifest ? manifest : Helpers::default_manifest
    end
  end

  def invoke()
    working_dir = "."
    module_infos = []
    if @manifest
      manifest = read_manifest(@manifest)
      remote_url = URI.parse(manifest.remote_url ? manifest.remote_url : "ssh://gerrit/")
      manifest.modules.each do |mod|
        if remote_url.relative?
          remote_path = File.join(manifest.remote_url, mod.remote_path) 
        else
          remote_path = remote_url.merge(mod.remote_path).to_s
        end      
        module_infos.push(ModuleInfo.new(remote_path, mod.local_path, mod.target_revision, mod.ignores))
      end
    elsif File.directory?(File.join(working_dir, ".rim"))
      status = StatusBuilder.new.fs_status(working_dir)
      status.modules.each do |mod|
        rim_info = mod.rim_info
        module_infos.push(ModuleInfo.new(rim_info.remote_url, mod.dir, rim_info.upstream, rim_info.ignores))
      end
    else
      @logger.error "The current directory is no rim project root."
    end
    
    helper = SyncHelper.new(working_dir, module_infos, @logger)
    if helper.ready?
      helper.sync                
    else
      @logger.error "The workspace git contains uncommitted changes."
    end
  end

end

end
end


