require 'rim/processor'
require 'rim/rim_info'

module RIM

class ModuleSyncHelper < Processor

  def initialize(workspace_root, module_info)
    super(workspace_root)
    @module_info = module_info
    @remote_path = remote_path(@module_info.remote_url)
  end

  # check whether module is ready for update
  def ready_for_update?
    local_changes?(@ws_root, @module_info.local_path)
  end

  # do the local sync without committing
  def sync
    fetch_module
    export_module                    
  end
  
  def commit
    RIM::git_session(:work_dir => @ws_root) do |s|
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
  
  # fetch module +mod+ into the .rim folder
  # works both for initial fetch and updates
  def fetch_module
    git_path = module_git_path(@remote_path)
    FileUtils.mkdir_p git_path
    RIM::git_session(:git_dir => git_path, :work_dir => "") do |s|
      if !File.exist?(git_path + "/config")
        s.execute("git clone --mirror #{@module_info.remote_url} #{git_path}")
      else
        s.execute("git remote update")
      end
    end
  end

  # export +revision+ of +mod+ into working copy
  # BEWARE: any changes to the working copy target dir will be lost!
  def export_module
    git_path = module_git_path(@remote_path)
    RIM::git_session(:git_dir => git_path, :work_dir => "") do |s|
      local_path = File.join(@ws_root, @module_info.local_path)
      FileUtils.rm_rf local_path if File.exist? local_path
      FileUtils.mkdir_p local_path
      s.execute("git archive --format tar #{@module_info.target_revision} | tar -x -C #{local_path}")
      sha1 = s.execute("git rev-parse #{@module_info.target_revision}").strip
      @rim_info = RimInfo.new
      @rim_info.remote_url = @module_info.remote_url
      @rim_info.upstream = @module_info.target_revision
      @rim_info.revision = sha1
      @rim_info.ignores = @module_info.ignores
      @rim_info.to_dir(local_path)
    end
  end

end

end
