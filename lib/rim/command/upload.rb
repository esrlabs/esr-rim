require 'rim/command/command'
require 'rim/processor'
require 'rim/upload_helper'

module RIM
module Command

class Upload < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim upload <local_module_path>"
    opts.description = "Upload rim modules according to manifest"
  end

  def invoke()
    helper = UploadHelper.new(".", @logger)
    helper.module_from_path(ARGV[0] || ".", :resolve_mode => :absolute)
    helper.upload                
  end

end

end
end


