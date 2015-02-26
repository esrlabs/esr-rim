require 'rim/processor'
require 'rim/module_sync_helper'

module RIM

class SyncHelper < Processor

  def initialize(workspace_root, module_infos)
    super(workspace_root)
    @module_helpers = []
    module_infos.each do |info|
      @module_helpers.push(ModuleSyncHelper.new(workspace_root, info))
    end
  end

  # check whether workspace is ready for sync
  def ready?
    local_changes?(@ws_root)
  end

  # sync all module changes into rim branch
  def sync
    # get the name of the current workspace branch
    RIM::git_session(:work_dir => @ws_root) do |s|
      branch = s.current_branch
      if !branch.start_with?("rim/")
        begin
          remote_rev = get_last_remote_revision(s, branch)
          rev = remote_rev ? remote_rev : branch
          rim_branch = "rim/" + branch
          checkout_rim_branch(s, rim_branch, rev)
          sync_modules
        ensure
          s.execute("git checkout #{branch}")
        end
      else
        puts "The current git branch '#{branch}' is a rim integration branch. Please switch to a non rim branch to proceed."
      end
    end
  end
  
private

  # sync all modules
  def sync_modules
    each_module_parallel("sync'ing", @module_helpers) do |m|
      m.sync
    end
    @module_helpers.each do |m|
      m.commit
    end
  end

  # checkout the rim branch
  def checkout_rim_branch(session, rim_branch, rev)
      if !session.has_branch?(rim_branch) || !has_ancestor?(session, rim_branch, rev)
        # the destination branch is not existing or is not ancestor of the last remote revision
        # => create the branch at the remote revision 
        session.execute("git checkout -B #{rim_branch} #{rev}")
      else
        # the destination branch is yet existing and has the remote revision as ancestor
        # => put the changes onto the current branch
        session.execute("git checkout #{rim_branch}")
      end
  end

  # get last remote revision the branch was synchronized with
  def get_last_remote_revision(session, rev)
    # remote revs are where we stop traversal
    non_remote_revs = {}
    session.all_reachable_non_remote_revs(rev).each do |r| 
      non_remote_revs[r] = true
    end
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    while rev && non_remote_revs[rev]
      parents = session.parent_revs(rev)
      rev = parents.size > 0 ? parents.first : nil
    end
    rev
  end

  # check whether revision has a given ancestor
  def has_ancestor?(session, rev, ancestor)
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    while rev && rev != ancestor
      parents = session.parent_revs(rev)
      rev = parents.size > 0 ? parents.first : nil
    end
    rev != nil
  end  

end

end
