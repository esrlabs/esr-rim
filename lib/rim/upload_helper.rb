require 'rim/command_helper'
require 'rim/upload_module_helper'

module RIM

class UploadHelper < CommandHelper

  def initialize(workspace_root, review, logger, module_infos = nil)
    @module_helpers = []
    @review = review
    super(workspace_root, logger, module_infos)
  end

  # upload all module changes into corresponding remote repositories
  def upload
    # get the name of the current workspace branch
    RIM::git_session(@ws_root) do |s|
      branch = s.current_branch
      if branch.nil?
        raise RimException.new("Not on a git branch.")
      elsif !branch.start_with?("rim/")
        begin
          sha1 = s.rev_sha1(branch)
          @logger.info("Uploading modules...")
          upload_modules(get_upload_revisions(s, sha1))
        ensure
          s.execute("git checkout -B #{branch}")
        end
      else
        raise RimException.new("The current git branch '#{branch}' is a rim integration branch. Please switch to a non rim branch to proceed.")
      end
    end
  end

  # called to add a module info
  def add_module_info(module_info)
    @module_helpers.push(UploadModuleHelper.new(@ws_root, module_info, @review, @logger))
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
