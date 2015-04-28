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
  # at the end of the chain, the status must be calculated in the regular "non-fast" way
  #
  def build_rev_history_status(gs, rev, relevant_revs, status_cache={})
    # * copy the status object from the parent commit
    # * check if .riminfo files were added or removed
    #   adapt the status object accordingly
    # * calc the dirty state for new modules and update the status object
    # * check if within this commit files were changed affecting any of the modules in the status object
    #   if so, re-calculate the dirty state for those modules and update the status object
    return status_cache[rev] if status_cache[rev]
    if relevant_revs[rev]
      parent_revs = gs.parent_revs(rev)
      if parent_revs.size > 0
        # build status for all parent nodes
        parent_stats = parent_refs.collect do |p|
          build_rev_history_status(gs, p, relevant_revs, status_cache)
        end

        # if this is a merge commit with multiple parents
        # we decide to use the first commit (git primary parent)
        # note that it's not really important, which one we choose
        # just make sure to use the same commit when checking for changed files
        base_stat = parent_stats.first
        
        changed_files = gs.changed_files(rev, parent_revs.first)

        # build list of modules in this commit
        module_dirs = base_stat.modules.collect{|m| m.dir}
        changed_files.each do |f|
          if File.basename(f.path) == RimInfo::InfoFileName
            if f.kind == :added
              module_dirs << File.dirname(f.path)
            elsif f.kind == :deleted
              module_dirs.delete(File.dirname(f.path))
            end
          end
        end

        # a module needs to be checked if any of the files within were touched
        check_dirs = module_dirs.select{|d| changed_files.any?{|f| f.path.start_with?(d)} }

        module_stats = []
        # check out all modules to be checked at once
        gs.within_exported_rev(rev, check_dirs) do |ws|
          # build module stats
          module_dirs.each do |d|
            if check_dirs.include?(d)
              module_stats << build_module_status(ws, File.join(ws, d))
            else
              base_mod = base_stat.modules.find{|m| m.dir == d}
              module_stats << RevStatus::ModuleStatus.new(d, base_mod.rim_info, base_mod.dirty?)
            end
          end
        end

        stat = RevStatus.new(module_stats)
        stat.git_rev = gs.rev_sha1(rev)
        stat.parents.concat(parent_stats)
      else
        # no parents, need to do a full check
        rev_status(gs, rev)
      end
    else
      # first "non-relevant", do the full check
      rev_status(gs, rev)
    end
  end

end

end
