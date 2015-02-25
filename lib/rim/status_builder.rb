require 'rim/rim_info'
require 'rim/rev_status'
require 'rim/dirty_check'

module RIM

class StatusBuilder

  # status object tree for revision rev
  # returns the root status object which points to any parent status objects
  # note that merge commits mean that the status tree branches
  # stops traversing when commits with remote labels on them are found
  # the leafs of the tree returned are commits to which remote labels point to
  # or ones which have no parents
  def rev_history_status(git_session, rev)
    # remote revs are where we stop traversal
    non_remote_revs = {}
    git_session.all_reachable_non_remote_revs(rev).each do |r| 
      non_remote_revs[r] = true
    end
    # make sure we deal only with sha1s
    rev = git_session.rev_sha1(rev)
    build_rev_history_status(git_session, rev, non_remote_revs)
  end

  # status object for revision rev
  def rev_status(git_session, rev)
    git_session.within_exported_rev(rev) do |d|
      stat = fs_status(d)
      stat.git_rev = git_session.rev_sha1(rev)
      stat
    end
  end

  # status object for the current file system content of dir
  # this can by any directory even outside of any git working copy
  def fs_status(dir)
    RevStatus.new(
      fs_rim_dirs(dir).collect { |d|
        build_module_status(dir, d) 
      })
  end

  private

  def build_rev_history_status(gs, rev, non_remote_revs, status_cache={})
    return status_cache[rev] if status_cache[rev]
    stat = rev_status(gs, rev)
    status_cache[rev] = stat
    if non_remote_revs[rev]
      # for each parent commit
      gs.parent_revs(rev).each do |p|
        stat.parents << build_rev_history_status(gs, p, non_remote_revs, status_cache)
      end
    end
    stat
  end

  def build_module_status(root_dir, dir)
    RevStatus::ModuleStatus.new(
      Pathname.new(dir).relative_path_from(Pathname.new(root_dir)).to_s,
      RimInfo.from_dir(dir),
      DirtyCheck.dirty?(dir)
    )
  end

  def fs_rim_dirs(dir)
    Dir.glob(dir+"/**/#{RimInfo::InfoFileName}").collect { |f|
      File.dirname(f)
    }
  end

end

end
