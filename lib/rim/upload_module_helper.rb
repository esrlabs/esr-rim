require 'rim/module_helper'
require 'rim/rim_info'
require 'rim/file_helper'
require 'rim/dirty_check'

module RIM

class UploadModuleHelper < ModuleHelper

  def initialize(workspace_root, module_info, logger)
    super(workspace_root, module_info, logger)
  end

  # do the module uploads for revisions given by sha
  def upload(parent, sha1s)
    fetch_module
    upload_module_changes(parent, sha1s)      
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

  # fetch module +mod+ into the .rim folder
  # works both for initial fetch and updates
  def fetch_module
    git_path = module_git_path(@remote_path)
    FileUtils.mkdir_p git_path
    RIM::git_session(git_path) do |s|
      if !File.exist?(File.join(git_path, ".git"))
        s.execute("git clone #{@module_info.remote_url} .")
      else
        s.execute("git fetch")
      end
    end
  end

  # upload the content of the module
  def upload_module_changes(parent_sha1, sha1s)
    # search for the first revision that is not 
    git_path = module_git_path(@remote_path)
    tmp_git_path = create_tmp_git
    RIM::git_session(tmp_git_path) do |dest|
      RIM::git_session(@ws_root) do |src|
        branch = nil
        for sha1 in sha1s do
          if dest.execute("git tag --list rim-#{sha1}").empty?
            rim_info = get_riminfo_for_revision(src, sha1)  
            if rim_info.revision
              branch = create_update_branch(dest, rim_info.revision, parent_sha1, sha1) if !branch
              copy_revision_files(src, sha1, tmp_git_path, rim_info.ignores)
              # get message for revision and commit them
              msg = src.execute("git show -s --format=%B #{sha1}")
              commit_changes(dest, branch, sha1, msg)
            end
          end
          parent_sha1 = sha1
        end
      end
      # Finally we're done. Push the changes
      dest.execute("git push --all #{@remote_path}")                              
    end
  end
  
  # create temporary git which allows us to copy the working space into
  def create_tmp_git
    tmp_git_path = module_tmp_git_path(@remote_path)
    FileUtils.mkdir_p(tmp_git_path)
    RIM::git_session(tmp_git_path) do |s|
      if !File.exist?(File.join(tmp_git_path, ".git"))
        s.execute("git clone #{@module_info.remote_url} .")
      else
        s.execute("git fetch")
      end
    end
    tmp_git_path
  end

  # commit changes to session
  def commit_changes(session, branch, sha1, msg)
    if session.status.lines.any?
      # add before commit because the path can be below a not yet added path
      session.execute("git add --all")
      session.execute("git commit -m \"#{msg}\"")
      # create tag
      session.execute("git tag rim-#{sha1} refs/heads/#{branch}")
    end
  end

  # get target revision for this module for workspace revision
  def get_riminfo_for_revision(session, sha1)
    rim_info = RimInfo.from_s(session.execute("git show #{sha1}:#{File.join(@module_info.local_path, RimInfo::InfoFileName)}"))    
  end 
  
  # create update branch for given revision
  def create_update_branch(session, dest_revision, src_parent, src_sha1)
    branch = "rim/#{src_sha1}" 
    session.execute("git checkout -B #{branch} #{dest_revision}")
    branch
  end

  # copy files from given source revision into destination dir
  def copy_revision_files(src_session, src_sha1, dest_dir, ignores)
    Dir.mktmpdir do |tmp_dir|
      src_session.execute("git archive --format tar #{src_sha1} #{@module_info.local_path} | tar -x -C #{tmp_dir}")
      tmp_module_dir = File.join(tmp_dir, @module_info.local_path)
      files = FileHelper.find_matching_files(tmp_module_dir, false, "/**/*", File::FNM_DOTMATCH)
      files.delete(".")
      files.delete("..")
      files.delete(RimInfo::InfoFileName)
      files -= FileHelper.find_matching_files(tmp_module_dir, false, ignores)
      # have source files now. Now clear destination folder and copy
      prepare_empty_folder(dest_dir, ".git/**/*")
      files.each do |f|
        path = File.join(dest_dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(File.join(tmp_module_dir, f), path)        
      end
    end 
  end 

end

end
