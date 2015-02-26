require 'rim/status_builder'

module RIM
module Command

class Check < Command

  def initialize(opts)
    # opts.banner = "Usage: rim check <from-rev> <to-rev>"
    # opts.description = "Checks if commits in given revision range or clean."
    @rev = ARGV.last
  end

  def invoke()
    root = project_git_dir
    RIM.git_session(root) do |gs|
      sb = RIM::StatusBuilder.new
      stat = sb.rev_history_status(gs, @rev)
      if any_dirty?(stat)
        # TODO: propagate exit code and don't exit here
        puts "dirty commits detected"
        exit(1)
      end
    end
  end

  private 

  def any_dirty?(stat)
    return true if stat.dirty?
    stat.parents.each do |p|
      return true if any_dirty?(p)
    end
    false
  end

end

end
end

