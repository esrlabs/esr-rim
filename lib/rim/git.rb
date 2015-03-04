require 'tmpdir'
require 'logger'

module RIM

# raised when there is an error emitted by git call
class GitException < Exception
  attr_reader :cmd, :exitstatus, :out
  def initialize(cmd, exitstatus, out)
    @cmd = cmd
    @exitstatus = exitstatus
    @out = out
  end
end

class GitSession

  attr_reader :execute_dir
  attr_reader :work_tree
  attr_reader :git_dir

  def initialize(logger, execute_dir, arg = {})
    @execute_dir = execute_dir
    if arg.is_a?(Hash)
      @work_dir = arg.has_key?(:work_dir) ? arg[:work_dir] : ""
      @git_dir = arg.has_key?(:git_dir) ? arg[:git_dir] : ""
    end
    @logger = logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.open(execute_dir, options = {})
    log = @logger || Logger.new($stdout)
    self.new(log, execute_dir, options)
  end

  def self.next_invocation_id
    @invocation_id ||= 0
    @invocation_id += 1
  end

  class Status
    attr_accessor :lines

    # X          Y     Meaning
    # -------------------------------------------------
    #           [MD]   not updated
    # M        [ MD]   updated in index
    # A        [ MD]   added to index
    # D         [ M]   deleted from index
    # R        [ MD]   renamed in index
    # C        [ MD]   copied in index
    # [MARC]           index and work tree matches
    # [ MARC]     M    work tree changed since index
    # [ MARC]     D    deleted in work tree
    # -------------------------------------------------
    # D           D    unmerged, both deleted
    # A           U    unmerged, added by us
    # U           D    unmerged, deleted by them
    # U           A    unmerged, added by them
    # D           U    unmerged, deleted by us
    # A           A    unmerged, both added
    # U           U    unmerged, both modified
    # -------------------------------------------------
    # ?           ?    untracked
    # !           !    ignored
    # -------------------------------------------------
    class Line
      attr_accessor :istat, :wstat, :file, :rename

      def untracked?
        istat == "?" && wstat == "?"
      end

      def ignored?
        istat == "!" && wstat == "!"
      end

      def unmerged?
        istat == "D" && wstat == "D" ||
        istat == "A" && wstat == "A" ||
        istat == "U" ||
        wstat == "U"
      end

    end
  end

  # returns the current branch
  def current_branch
    execute 'git branch | grep "*" | sed "s/* //" | awk \'{printf $0}\''
  end
  
  # check whether branch exists
  def has_branch?(branch)
    execute("git show-ref refs/heads/#{branch}") do |b, e|
      return !e
    end
  end 

  # returns the parent commits of rev as SHA-1s 
  # returns an empty array if there are no parents (e.g. orphan or initial)
  def parent_revs(rev)
    out = execute "git rev-list -n 1 --parents #{rev} --"
    out.strip.split[1..-1]
  end

  # returns the SHA-1 representation of rev
  def rev_sha1(rev)
    out = execute "git rev-list -n 1 #{rev} --"
    out.strip
  end

  # returns the SHA-1 representations of the heads of all remote branches
  def remote_branch_revs
    out = execute "git show-ref"
    out.split("\n").collect { |l|
      if l =~ /refs\/remotes\//
        l.split[0]
      else
        nil
      end
    }.compact
  end

  # all commits reachable from rev which are not ancestors of remote branches
  def all_reachable_non_remote_revs(rev)
    out = execute "git rev-list #{rev} --not --remotes --"
    out.split("\n")
  end

  # export file contents of rev to dir
  # does not remove any files from dir which existed before
  def export_rev(rev, dir)
    execute "git archive --format tar #{rev} | tar -x -C #{dir}"
  end

  # checks out rev to a temporary directory and yields this directory to the given block
  # returns the value returned by the block
  def within_exported_rev(rev)
    Dir.mktmpdir("rim") do |d|
      export_rev(rev, d)
      # return contents of yielded block
      # mktmpdir returns value return by our block
      yield d
    end
  end
    
  def uncommited_changes?
    # either no status lines are all of them due to ignored items
    !status.lines.all?{|l| l.ignored?}
  end

  def current_branch_name
    out = execute "git rev-parse --abbrev-ref HEAD"
    out.strip
  end

  def status(dir = nil)
    # -s            short format
    # --ignored     show ignored
    out = execute "git status -s --ignored #{dir}"
    parse_status(out)
  end

  def execute(cmd)
    raise "git command has to start with 'git'" unless cmd.start_with? "git "
    cmd.slice!("git ")
    options = (@execute_dir.empty? ? "" : " -C #{@execute_dir}") \
        + (@work_dir.empty? ? "" : " --work-tree=#{File.expand_path(@work_dir)}") \
        + (@git_dir.empty? ? "" : " --git-dir=#{File.expand_path(@git_dir)}") 
    cmd = "git#{options} #{cmd} 2>&1"

    out = `#{cmd}`
    exitstatus = $?.exitstatus

    invid = self.class.next_invocation_id.to_s.ljust(4)
    @logger.debug "git##{invid} \"#{cmd}\" => #{exitstatus}" 

    out.split(/\r?\n/).each do |ol|
      @logger.debug "git##{invid} out : #{ol}"
    end

    exception = exitstatus != 0 ? GitException.new(cmd, exitstatus, out) : nil
    
    if block_given?
      yield out, exception  
    elsif exception
      @logger.error "git##{invid} \"#{cmd}\" => #{exitstatus}" 
      raise exception
    end

    out
  end

  private

  def parse_status(out)
    status = Status.new
    status.lines = []
    out.split(/\r?\n/).each do |l|
      sl = Status::Line.new
      sl.istat, sl.wstat = l[0], l[1]
      f1, f2 = l[3..-1].split(" -> ")
      f1 = unquote(f1)
      f2 = unquote(f2) if f2
      sl.file = f1
      sl.rename = f2
      status.lines << sl
    end
    status
  end

  def unquote(s)
    if s[0] == "\"" && s[-1] == "\""
      s = s[1..-2]
      s.gsub!("\\\\", "\\")
      s.gsub!("\\\"", "\"")
      s.gsub!("\\t", "\t")
      s.gsub!("\\r", "\r")
      s.gsub!("\\n", "\n")
    end
    s
  end

end

def RIM.git_session(execute_dir, options = {})
  s = GitSession.open(execute_dir, options)
  yield s
end

end
