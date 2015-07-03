module RIM

# RIM revision status object.
#
# Revision status objects hold the RIM status of a specific project git revision.
# As a special case, this could also be the status of the current working copy.
#
# The revision status consists of a set of module status objects,
# one for each module known to RIM in that revision. 
# The module status points to a RimInfo object holding attribute values 
# valid for that specific revision as well as the current dirty state as
# calculated by DirtyCheck and the module directory.
#
# Revsion status objects can have parent status objects. This way,
# chains and even trees of status objects can be built. For example in
# case of a merge commit, the corresponding status object would have
# two parent status objects, one for each parent git commit.
#
class RevStatus
  # git revision (sha1) for which this status was created
  # or nil if the status wasn't created for a git revision
  attr_reader :git_rev
  # module status objects
  attr_reader :modules
  # references to RevStatus objects of parent commits
  attr_reader :parents
  
  class ModuleStatus
    # module directory, relative to project dir root
    attr_reader :dir
    # reference to a RimInfo object
    attr_reader :rim_info

    # dirty state [true, false]
    def dirty?
      @dirty
    end

    def initialize(dir, rim_info, dirty)
      @dir = dir
      @rim_info = rim_info
      @dirty = dirty
    end
  end

  def initialize(modules)
    @modules = modules
    @parents = []
  end

  def dirty?
    modules.any?{|m| m.dirty?}
  end

  def git_rev=(rev)
    @git_rev = rev
  end

end

end
