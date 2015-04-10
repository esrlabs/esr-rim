require 'rim/command_helper'
require 'rim/sync_module_helper'
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
  def sync(message = nil)
    check_ready
    # get the name of the current workspace branch
    RIM::git_session(@ws_root) do |s|
      branch = s.current_branch
      rim_branch = "rim/" + branch
      branch_sha1 = nil
      if branch.empty?
        raise RimException.new("Not on a git branch.")
      elsif branch.start_with?("rim/")
        raise RimException.new("The current git branch '#{branch}' is a rim integration branch. Please switch to a non rim branch to proceed.")
      else
        remote_rev = get_branch_start_revision(s, branch)
        rev = remote_rev ? remote_rev : branch
        branch_sha1 = s.rev_sha1(rev)
        remote_url = "file://" + @ws_root
        create_rim_branch(s, rim_branch, rev)
        tmpdir = clone_or_fetch_repository(remote_url, module_tmp_git_path(".ws"))
        RIM::git_session(tmpdir) do |tmp_session|
          if tmp_session.rev_sha1(rim_branch)
            tmp_session.execute("git checkout --detach #{rim_branch}")
            tmp_session.execute("git branch -D #{rim_branch}")
          end 
          tmp_session.execute("git checkout #{rim_branch}")
          sync_modules(tmp_session, message)
          tmp_session.execute("git push #{remote_url} #{rim_branch}:#{rim_branch}")
        end
      end
      if s.rev_sha1(rim_branch) != branch_sha1
        @logger.info("Changes have been commited to branch #{rim_branch}. Rebase to apply changes to workspace.")
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
      module_helpers.push(SyncModuleHelper.new(session.execute_dir, module_info, @logger))
    end
    each_module_parallel("sync'ing", module_helpers) do |m|
      m.sync
    end
    module_helpers.each do |m|
      m.commit(message)
    end
  end

  # create the rim branch at the correct location
  def create_rim_branch(session, rim_branch, rev)
      if !session.has_branch?(rim_branch) || !has_ancestor?(session, rim_branch, rev)
        # the destination branch is not existing or is not ancestor of the last remote revision
        # => create the branch at the remote revision 
        session.execute("git branch -f #{rim_branch} #{rev}")
      end
  end

  # get revision where the branch should start
  def get_branch_start_revision(session, rev)
    # remote revs are where we stop traversal
    non_remote_revs = {}
    session.all_reachable_non_remote_revs(rev).each do |r| 
      non_remote_revs[r] = true
    end
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    while rev && non_remote_revs[rev] && !has_changed_riminfo?(session, rev) 
      rev = get_parent(session, rev)
    end
    rev
  end

  # check whether revision has a changed .riminfo file
  def has_changed_riminfo?(session, rev)
    session.execute("git show --name-only --oneline #{rev}") =~ /\/\.riminfo$/
  end

  # check whether revision has a given ancestor
  def has_ancestor?(session, rev, ancestor)
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    while rev && rev != ancestor
      rev = get_parent(session, rev)
    end
    rev != nil
  end
  
  # get first parent node
  def get_parent(session, rev)
    parents = session.parent_revs(rev)
    !parents.empty? ? parents.first : nil 
  end  

end

end
