require 'rim/module_helper'
require 'rim/rim_info'
require 'rim/file_helper'
require 'rim/dirty_check'

module RIM
  class SyncModuleHelper < ModuleHelper
    def initialize(workspace_root, module_info, logger)
      super(workspace_root, module_info, logger)
    end

    # do the local sync without committing
    def sync
      fetch_module
      export_module
    end

    def commit
      RIM::git_session(@ws_root) do |s|
      # do we need to commit something?
        stat = s.status(@module_info.local_path)
        if stat.lines.any?
          msg = "module #{@remote_path}: #{@rim_info.revision}"
          # add before commit because the path can be below a not yet added path
          s.execute("git add #{@module_info.local_path}")
          s.execute("git commit #{@module_info.local_path} -m \"#{msg}\"")
        end
      end
    end

    private

    # export +revision+ of +mod+ into working copy
    # BEWARE: any changes to the working copy target dir will be lost!
    def export_module
      git_path = module_git_path(@remote_path)
      RIM::git_session(git_path) do |s|
        local_path = File.join(@ws_root, @module_info.local_path)
        prepare_empty_folder(local_path, @module_info.ignores)
        s.execute("git archive --format tar #{@module_info.target_revision} | tar -x -C #{local_path}")
        sha1 = s.execute("git rev-parse #{@module_info.target_revision}").strip
        @rim_info = RimInfo.new
        @rim_info.remote_url = @module_info.remote_url
        @rim_info.upstream = @module_info.target_revision
        @rim_info.revision = sha1
        @rim_info.ignores = @module_info.ignores.join(",")
        @rim_info.to_dir(local_path)
        DirtyCheck.mark_clean(local_path)
      end
    end

  end

end
