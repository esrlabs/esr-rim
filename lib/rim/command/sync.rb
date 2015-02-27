require 'rim/command/command'
require 'rim/manifest/helper'
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
    helper = SyncHelper.new(".", @logger)
    if @manifest
      helper.modules_from_manifest(@manifest)
    elsif !helper.modules_from_workspace
      @logger.error "The current directory is no rim project root."
    end

    if helper.ready?
      helper.sync                
    else
      @logger.error "The workspace git contains uncommitted changes."
    end
  end

end

end
end


