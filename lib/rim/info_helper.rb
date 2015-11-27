require 'rim/command_helper'
require 'rim/info_module_helper'

module RIM

class InfoHelper < CommandHelper

  def initialize(workspace_root, logger)
    @module_helpers = []
    super(workspace_root, logger)
  end

  def add_module_info(module_info)
    @module_helpers.push(InfoModuleHelper.new(@ws_root, module_info, @logger))
  end

  def upstream_info
    each_module_parallel("gather info", @module_helpers) do |m|
      print "."
      m.gather_info
    end
    puts
    @module_helpers.each do |h|
      path = h.module_info.local_path.split(/[\\\/]/).last.ljust(40)
      info = "#{path}: ->#{h.target_rev.ljust(10)} @#{h.current_sha1[0..6]}"
      if h.upstream_revs
        if h.upstream_revs.size > 0
          info += " [#{h.upstream_revs.size} commits behind]"
        else
          info += " [UP TO DATE]"
        end
        @logger.info(info)
        h.upstream_revs.each do |r|
          @logger.info("  #{r.strip}")
        end
      else
        @logger.info(info)
      end
    end
  end

end

end

