require 'rim/rim_info'
require 'rim/rev_status'
require 'rim/dirty_check'

module RIM

class StatusBuilder

  # status object tree for revision rev
  # returns the root status object which points to any parent status objects
  # note that merge commits mean that the status tree branches
  # at the point were the merged branch branched off, the status tree joins
  # i.e. the parent status objects are the same at this point
  #
  # stops traversing a specific branch when a commit is found which is an ancestor
  # of :stop_rev or any remote branch if :stop_rev is not provided 
  #
  # the leafs of the tree are the stop commits or commits which have no parents
  #
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

  # status object for single revision +rev+ without status of ancestors
  def rev_status(git_session, rev)
    out =git_session.execute("git ls-tree -r --name-only #{rev}")
    mod_dirs = []
    out.split("\n").each do |l|
      if File.basename(l) == RimInfo::InfoFileName
        mod_dirs << File.dirname(l)
      end
    end
    mod_stats = []
    # export all relevant modules at once
    # this makes status calculation significantly faster compared
    # to exporting each module separately 
    # (e.g. 1.0s instead of 1.5s on linux for a commit with 20 modules)
    git_session.within_exported_rev(rev, mod_dirs) do |d|
      mod_dirs.each do |rel_path|
        mod_stats << build_module_status(d, d+"/"+rel_path)
      end
    end
    stat = RevStatus.new(mod_stats)
    stat.git_rev = git_session.rev_sha1(rev)
    stat
  end

  # status object for a single module at +local_path+ in revision +rev+
  # returns nil if there is no such module in this revision
  def rev_module_status(git_session, rev, local_path)
    mod_stat = nil
    if git_session.execute("git ls-tree -r --name-only #{rev}").split("\n").include?(File.join(local_path, ".riminfo"))
      git_session.within_exported_rev(rev, [local_path]) do |d|
        mod_stat = build_module_status(d, File.join(d, local_path))
      end
    end
    mod_stat
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

  # fast building of the status of an ancestor chain works by checking
  # the dirty state of modules only when any files affecting some module 
  # were changed; otherwise the status of the module in the ancestor is assumed
  #
  # for this to work, the chain must be walked from older commit to newer ones
  #
  # at the end of the chain, the status must be calculated for the last node;
  # there are two options for that:
  #
  # 1. examine the dirty state for each module present it that commit
  # 2. find all modules and assume the state is clean
  #
  # option 2 is faster for repositories with many modules; normally it's also
  # safe to assume the start commits are clean since those are normally 
  # remote commits which have been checked before; however, this may depend
  # on how the user uses rim
  #
  def build_rev_history_status_fast(gs, rev, relevant_revs, status_cache={})
    # * copy the status object from the parent commit
    # * check if .riminfo files were added or removed
    #   adapt the status object accordingly
    # * calc the dirty state for new modules and update the status object
    # * check if within this commit files were changed affecting any of the modules in the status object
    #   if so, re-calculate the dirty state for those modules and update the status object
    return status_cache[rev] if status_cache[rev]
    if relevant_revs[rev]
      parent_stats = gs.parent_revs(rev).collect do |p|
        build_rev_history_status_fast(gs, p, relevant_revs, status_cache)
      end
      if parent_stats.size > 0
        base_stat = parent_stats.first
      else
        # no parents, empty base status object
        base_stat = RevStatus.new
      end
    else
    end
    stat
  end

  def build_start_node_status(gs, rev, mode)
    if mode == :fast
      build_rev_status_fast(gs, rev)
    else
      rev_status(gs, rev)
    end
  end

  def build_rev_status_fast(gs, rev)
    out = gs.execute("git ls-tree -r --name-only #{rev}")
    mod_stats = []
    out.split("\n").each do |l|
      if File.basename(l) == RimInfo::InfoFileName
        rel_path = File.dirname(l)
        mod_stats << RevStatus::ModuleStatus.new(
          File.join(gs.execute_dir, rel_path),
          RimInfo.from_dir(dir),
          DirtyCheck.dirty?(dir)
        )
      end
    end
    stat = RevStatus.new(mod_stats)
    stat.git_rev = gs.rev_sha1(rev)
    stat
  end

end

end
