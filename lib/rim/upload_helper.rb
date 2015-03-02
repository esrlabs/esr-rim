require 'rim/command_helper'
require 'rim/upload_module_helper'

module RIM

class UploadHelper < CommandHelper

  def initialize(workspace_root, logger)
    super(workspace_root, logger)
    @module_helpers = []
    @logger = logger
  end

  # upload all module changes into corresponding remote repositories
  def upload
    # get the name of the current workspace branch
    RIM::git_session(:work_dir => @ws_root) do |s|
      branch = s.current_branch
      if !branch.start_with?("rim/")
        begin
          sha1 = rev_sha1(branch)
          upload_modules(get_upload_revisions(s, sha1))
        ensure
          s.execute("git checkout #{branch}")
        end
      else
        @logger.error "The current git branch '#{branch}' is a rim integration branch. Please switch to a non rim branch to proceed."
      end
    end
  end

protected
  # called to add a module info
  def add_module_info(module_info)
    @module_helpers.push(UploadModuleHelper.new(@ws_root, module_info, @logger))
  end
  
private
  # upload all modules
  def upload_modules(info)
    each_module_parallel("uploading", @module_helpers) do |m|
      m.upload(info.parent, info.sha1s)
    end
  end

  # get revisions to upload i.e. the revisions up to the last remote revision
  # the function returns the revisions in order of appearal i.e. the oldest first 
  def get_upload_revisions(session, rev)
    # remote revs are where we stop traversal
    non_remote_revs = {}
    session.all_reachable_non_remote_revs(rev).each do |r| 
      non_remote_revs[r] = true
    end
    revisions = []
    # make sure we deal only with sha1s
    rev = session.rev_sha1(rev)
    while rev && non_remote_revs[rev]
      revisions.push(rev)
      parents = session.parent_revs(rev)
      rev = parents.size > 0 ? parents.first : nil
    end
    Struct.new(:parent, :sha1s).new(rev, revisions.reverse!)
  end

end

end
