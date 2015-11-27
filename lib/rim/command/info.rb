require 'rim/command/command'
require 'rim/info_helper'

module RIM
module Command

class Info < Command

  def initialize(opts)
    opts.banner = "Usage: rim info [<options>] [<local_module_path>]"
    opts.description = "Prints information about RIM modules in <local_module_path> or all modules if omitted"
    opts.separator ""
    opts.on("-d", "--detailed", "print detailed information") do
      @detailed = true
    end
  end

  def invoke
    helper = InfoHelper.new(project_git_dir, @logger)
    helper.modules_from_paths(helper.module_paths(ARGV))
    helper.upstream_info
  end

end

end
end

