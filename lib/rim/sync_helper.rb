require 'rim/command_helper'
require 'rim/sync_module_helper'
require 'rim/status_builder'
require 'tempfile'
require 'fileutils'

module RIM

class SyncHelper < CommandHelper

  def initialize(workspace_root, logger, module_infos = nil)
    @module_infos = []
    super(workspace_root, logger, module_infos)
  end

  # called to add a module info
  def add_module_info(module_info)
    @module_infos.push(module_info)
  end

  # sync all module changes into rim branch
  def sync(message = nil, rebase = nil, split = true)
    # get the name of the current workspace branch
    RIM::git_session(@ws_root) do |s|
      branch = s.current_branch || ''
      rim_branch = "rim/" + branch
      branch_sha1 = nil
      changed_modules = nil
      if branch.empty?
        raise RimException.new("Not on a git branch.")
      elsif branch.start_with?("rim/")
        raise RimException.new("The current git branch '#{branch}' is a rim integration branch. Please switch to a non rim branch to proceed.")
      else
        branch_sha1 = s.rev_sha1(rim_branch)
        remote_rev = get_latest_remote_revision(s, branch)
        rev = get_latest_clean_path_revision(s, branch, remote_rev)
        if !s.has_branch?(rim_branch) || has_ancestor?(s, branch, s.rev_sha1(rim_branch)) || !has_ancestor?(s, rim_branch, remote_rev)
          s.execute("git branch -f #{rim_branch} #{rev}")
          branch_sha1 = s.rev_sha1(rim_branch)
        end
        remote_url = "file://" + @ws_root
        @logger.debug("Folder for temporary git repositories: #{@rim_path}")
        tmpdir = clone_or_fetch_repository(remote_url, module_tmp_git_path(".ws"), "Cloning workspace git...")
        RIM::git_session(tmpdir) do |tmp_session|
          tmp_session.execute("git reset --hard")
          tmp_session.execute("git clean -xdf")
          # use -f here to prevent git checkout from checking for untracked files which might be overwritten. 
          # this is safe since we removed any untracked files before.
          # this is a workaround for a name case problem on windows:
          # if a file's name changes case between the current head and the checkout target,
          # git checkout will report the file with the new name as untracked and will fail
          tmp_session.execute("git checkout -B #{rim_branch} -f remotes/origin/#{rim_branch}")
          changed_modules = sync_modules(tmp_session, message)
          if !split
            tmp_session.execute("git reset --soft #{branch_sha1}")
            commit(tmp_session, message ? message : get_commit_message(changed_modules)) if tmp_session.uncommited_changes?
          end
          tmp_session.execute("git push #{remote_url} #{rim_branch}:#{rim_branch}")
        end
      end
      if !changed_modules.empty?
        if rebase
          s.execute("git rebase #{rim_branch}")
          @logger.info("Changes have been commited to branch #{rim_branch} and workspace has been rebased successfully.")
        else
          @logger.info("Changes have been commited to branch #{rim_branch}. Rebase to apply changes to workspace.")
        end
      else
        @logger.info("No changes.")
      end
    end
  end

private
  # sync all modules
  def sync_modules(session, message)
    module_helpers = []
    @module_infos.each do |module_info|
      module_helpers.push(SyncModuleHelper.new(session.execute_dir, @ws_root, module_info, @logger))
    end
    changed_modules = []
    module_helpers.each do |m|
      @logger.info("Synchronizing #{m.module_info.local_path}...")
      if m.sync(message)
        changed_modules << m.module_info
      end
    end
    changed_modules
  end

  # get latest revision from which all parent revisions are clean 
  def get_latest_clean_path_revision(session, rev, remote_rev)
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    # get history status (up to last remote revision)
    status = StatusBuilder.new().rev_history_status(session, rev, :fast => true)
    clean_rev = rev;
    while status
      dirty = status.dirty?
      status = !status.parents.empty? ? status.parents[0] : nil  
      clean_rev = status ? status.git_rev : remote_rev if dirty
    end
    clean_rev
  end

  # get latest remote revision
  def get_latest_remote_revision(session, rev)
    # remote revs are where we stop traversal
    non_remote_revs = {}
    session.all_reachable_non_remote_revs(rev).each do |r| 
      non_remote_revs[r] = true
    end
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    start_rev = rev;
    while rev && non_remote_revs[rev]
      rev = get_parent(session, rev)
    end
    rev
  end

  # check whether revision has a given ancestor
  def has_ancestor?(session, rev, ancestor)
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    return rev == ancestor || session.is_ancestor?(ancestor, rev)
  end
  
  # get first parent node
  def get_parent(session, rev)
    parents = session.parent_revs(rev)
    !parents.empty? ? parents.first : nil 
  end  

  #create default commit message from array of changed modules
  def get_commit_message(changed_modules)
    StringIO.open do |s|
      s.puts "rim sync."
      s.puts
      changed_modules.each do |m|
        s.puts m.local_path
      end
      s.string
    end
  end

end

end
