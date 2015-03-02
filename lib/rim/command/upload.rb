require 'rim/command/command'
require 'rim/processor'
require 'rim/upload_helper'

module RIM
module Command

class Upload < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim upload <local_module_path>+"
    opts.description = "Upload rim modules according to manifest"
  end

  def invoke()
    helper = UploadHelper.new(".", @logger)
    if helper.modules_from_workspace
      if helper.ready?
        helper.upload                
      else
        @logger.error "The workspace git contains uncommitted changes."
      end
    else
      @logger.error "The current directory is no rim project root."
    end

  end

end

end
end


