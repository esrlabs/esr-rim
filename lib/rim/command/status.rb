require 'rim/status_builder'

module RIM
module Command

class Status < Command

  def initialize(opts)
    opts.banner = "Usage: rim status [--verify-clean] [<from-rev>..<to-rev>]"
    opts.description = "Prints commits and their RIM status."

# Without revision arguments checks the current branch and all local ancestors.
# Otherwise checks <to-rev> and all its ancestors excluding ancestors of <from-rev>.
# 
# With the --verify-clean options, exit with error code 1 if any commits are in dirty state.

    opts.on("-d", "--detailed", "print detailed status") do
      @detailed = true
    end
    opts.on("--verify-clean", "exit with error code 1 if commits are dirty") do
      @verify_clean = true
    end
  end

  def invoke()
    root = project_git_dir
    rev_range = ARGV.shift
    stat = nil
    RIM.git_session(root) do |gs|
      sb = RIM::StatusBuilder.new
      if rev_range
        from_rev, to_rev = rev_range.split("..")
        stat = sb.rev_history_status(gs, to_rev, :stop_rev => from_rev)
        print_status(gs, stat)
      else
        if gs.uncommited_changes?
          stat = sb.fs_status(root)
          print_status(gs, stat)
        end
        branch = gs.current_branch_name
        stat = sb.rev_history_status(gs, branch)
        print_status(gs, stat)
      end
    end
    if @verify_clean && any_dirty?(stat)
      exit(1)
    end
  end

  private 

  def any_dirty?(stat)
    stat.dirty? || stat.parents.any?{|p| any_dirty?(p)}
  end

  def print_status(gs, stat)
    # don't print the last (remote) status nodes
    # note: this also excludes the initial commit
    return if stat.git_rev && stat.parents.empty?
    dirty_mods = stat.modules.select{|m| m.dirty?}
    stat_info = dirty_mods.empty? ? "[   OK]" : "[DIRTY]"
    if stat.git_rev
      out = gs.execute "git rev-list --format=oneline -n 1 #{stat.git_rev}" 
      if out =~ /^(\w+) (.*)/
        sha1, comment = $1, $2
        @logger.info "#{stat_info} #{sha1[0..6]} #{comment}"
      end
    else
      @logger.info "#{stat_info} ------- uncommitted changes"
    end
    if @detailed
      puts
      dirty_mods.each do |m|
        @logger.info "        - #{m.dir}"
      end
    elsif dirty_mods.size > 0
      @logger.info " (#{dirty_mods.size} modules dirty)"
    else
      @logger.info
    end
    stat.parents.each do |p|
      print_status(gs, p)
    end
  end

end

end
end
