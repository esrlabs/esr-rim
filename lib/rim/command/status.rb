require 'rim/status_builder'

module RIM
module Command

class Status < Command

  def initialize(opts)
    # opts.banner = "Usage: rim status"
    # opts.description = "Print local commits and their status"
    @detailed = false
  end

  def invoke()
    root = project_git_dir
    RIM.git_session(root) do |gs|
      sb = RIM::StatusBuilder.new
      if gs.uncommited_changes?
        stat = sb.fs_status(root)
        print_status(gs, stat)
      end
      branch = gs.current_branch_name
      stat = sb.rev_history_status(gs, branch)
      print_status(gs, stat)
    end
  end

  private 

  def print_status(gs, stat)
    dirty_mods = stat.modules.select{|m| m.dirty?}
    stat_info = dirty_mods.empty? ? "[   OK]" : "[DIRTY]"
    if stat.git_rev
      out = gs.execute "git rev-list --format=oneline -n 1 #{stat.git_rev}" 
      if out =~ /^(\w+) (.*)/
        sha1, comment = $1, $2
        print "#{stat_info} #{sha1[0..6]} #{comment}"
      end
    else
      print "#{stat_info} ------- uncommitted changes"
    end
    if @detailed
      puts
      dirty_mods.each do |m|
        puts "        - #{m.dir}"
      end
    elsif dirty_mods.size > 0
      puts " (#{dirty_mods.size} modules dirty)"
    else
      puts
    end
    stat.parents.each do |p|
      print_status(gs, p)
    end
  end

end

end
end
