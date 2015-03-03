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
    upload_module_changes(parent, sha1s)      
  end
  
private

  # upload the content of the module
  def upload_module_changes(parent_sha1, sha1s)
    remote_path = fetch_module
    # search for the first revision that is not 
    tmp_git_path = clone_or_fetch_repository(remote_path, module_tmp_git_path(@remote_path))
    RIM::git_session(tmp_git_path) do |dest|
      local_branch = nil
      remote_branch = nil
      RIM::git_session(@ws_root) do |src|
        infos = get_branches_and_revision_infos(src, dest, parent_sha1, sha1s)
        if infos.branches.size == 1
          remote_branch = @module_info.remote_branch_decoration ? @module_info.remote_branch_decoration % infos.branches[0] : infos.branches[0]
          if dest.has_branch?(remote_branch)
            infos.rev_infos.each do |rev_info|
              local_branch = create_update_branch(dest, rev_info.dest_sha1, rev_info.src_sha1) if !local_branch
              copy_revision_files(src, rev_info.src_sha1, tmp_git_path, infos.rev_infos.last.rim_info.ignores)
              commit_changes(dest, local_branch, rev_info.src_sha1, rev_info.message)
            end
          else
            @logger.error "Module #{@module_info.local_path} is not based on branch. No push can be performed."
          end
        else
          @logger.error "There are commits for module #{@module_info.local_path} on multiple target revisions (#{info.branches.join(", ")})."
        end
      end
      # Finally we're done. Push the changes
      if local_branch
        dest.execute("git push #{@module_info.remote_url} #{local_branch}:#{remote_branch}")
        dest.execute("git checkout --detach #{local_branch}")
        dest.execute("git branch -D #{local_branch}")
      end                              
    end
  end

  # search backwards for all revision infos
  def get_branches_and_revision_infos(src_session, dest_session, parent_sha1, sha1s)
    infos = []
    branches = []
    (sha1s.size() - 1).step(0, -1) do |i|
      info = get_revision_info(src_session, dest_session, sha1s[i])
      if info
        infos.unshift(info)
        branches.push(info.rim_info.upstream) if !branches.include?(info.rim_info.upstream)
      else
        parent_sha1 = sha1s[i - 1] if i > 0
        break
      end
    end
    return Struct.new(:branches, :parent_sha1, :rev_infos).new(branches, parent_sha1, infos)      
  end

  # collect infos for a revision
  def get_revision_info(src_session, dest_session, src_sha1)
    info = nil
    dest_sha1 = dest_session.execute("git tag --list rim-#{src_sha1}")
    if dest_sha1.empty?
      rim_info = get_riminfo_for_revision(src_session, src_sha1)
      msg = src_session.execute("git show -s --format=%B #{src_sha1}")
      if rim_info.revision
        info = Struct.new(:dest_sha1, :src_sha1, :rim_info, :message).new(rim_info.revision, src_sha1, rim_info, msg)
      end
    end
    info
  end
  
  # clone or fetch repository
  def clone_or_fetch_repository(remote_url, local_path)
    FileUtils.mkdir_p local_path
    RIM::git_session(local_path) do |s|
      if !File.exist?(File.join(local_path, ".git"))
        s.execute("git clone #{remote_url} .")
      else
        s.execute("git fetch")
      end
    end
    local_path
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
    session.execute("git show #{sha1}:#{File.join(@module_info.local_path, RimInfo::InfoFileName)}") do |out, e|
      return RimInfo.from_s(!e ? out : "")
    end
  end 
  
  # create update branch for given revision
  def create_update_branch(session, dest_sha1, src_sha1)
    branch = "rim/#{src_sha1}" 
    session.execute("git checkout -B #{branch} #{dest_sha1}")
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
