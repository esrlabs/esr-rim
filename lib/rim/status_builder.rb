require 'rim/rim_info'
require 'rim/rev_status'
require 'rim/dirty_check'

module RIM

class StatusBuilder

  # status object tree for revision rev
  # returns the root status object which points to any parent status objects
  # note that merge commits mean that the status tree branches
  # stops traversing a specific branch when a commit is found which is an ancestor
  # of :stop_rev or any remote branch if :stop_rev is not provided 
  # the leafs of the tree are the stop commits or commits which have no parents
  def rev_history_status(git_session, rev, options={})
    stop_rev = options[:stop_rev]
    relevant_revs = {}
    if stop_rev
      git_session.execute("git rev-list #{rev} \"^#{stop_rev}\"").split("\n").each do |r|
        relevant_revs[r] = true
      end
    else
      # remote revs are where we stop traversal
      git_session.all_reachable_non_remote_revs(rev).each do |r| 
        relevant_revs[r] = true
      end
    end
    # make sure we deal only with sha1s
    rev = git_session.rev_sha1(rev)
    build_rev_history_status(git_session, rev, relevant_revs)
  end

  # status object for revision rev
  def rev_status(git_session, rev)
    out =git_session.execute("git ls-tree -r --name-only #{rev}")
    mod_stats = []
    out.split("\n").each do |l|
      if File.basename(l) == RimInfo::InfoFileName
        rel_path = File.dirname(l)
        git_session.within_exported_rev(rev, rel_path) do |d|
          mod_stats << build_module_status(d, d+"/"+rel_path)
        end
      end
    end
    stat = RevStatus.new(mod_stats)
    stat.git_rev = git_session.rev_sha1(rev)
    stat
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

  def build_rev_history_status(gs, rev, relevant_revs, status_cache={})
    return status_cache[rev] if status_cache[rev]
    stat = rev_status(gs, rev)
    status_cache[rev] = stat
    if relevant_revs[rev]
      # for each parent commit
      gs.parent_revs(rev).each do |p|
        stat.parents << build_rev_history_status(gs, p, relevant_revs, status_cache)
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
