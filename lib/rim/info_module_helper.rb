require 'rim/module_helper'

module RIM

class InfoModuleHelper < ModuleHelper

  attr_accessor :target_rev
  attr_accessor :current_sha1
  attr_accessor :upstream_revs
  attr_accessor :upstream_non_fast_forward

  def initialize(workspace_root, module_info, logger)
    super(workspace_root, module_info, logger)
  end

  def gather_info
    fetch_module
    rim_info = RimInfo.from_dir(File.join(@ws_root, @module_info.local_path))
    @target_rev = rim_info.target_revision
    @current_sha1 = rim_info.revision_sha1
    RIM::git_session(git_path) do |s|
      if s.has_remote_branch?(target_rev)
        # repository is mirrored so branches are "local"
        if s.is_ancestor?(current_sha1, target_rev)
          @upstream_revs = s.execute("git rev-list --oneline #{target_rev} \"^#{current_sha1}\"").split("\n")
        else
          @upstream_non_fast_forward = true
        end
      end
    end
  end

end

end
