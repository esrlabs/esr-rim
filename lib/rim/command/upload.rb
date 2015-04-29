require 'rim/command/command'
require 'rim/processor'
require 'rim/upload_helper'

module RIM
module Command

class Upload < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim upload <local_module_path>"
    opts.description = "Upload changes from rim module synchronized to <local_module_path> to remote repository."
  end

  def invoke()
    helper = UploadHelper.new(project_git_dir, @logger)
    helper.modules_from_paths(ARGV)
    helper.check_arguments
    helper.upload                
  end

end

end
end


