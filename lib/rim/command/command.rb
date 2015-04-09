module RIM
module Command

class Command
  attr_writer :logger

  def initialize(processor)
    @processor = processor
  end

  def project_git_dir
    git_dir = find_git_dir(".")
    raise RimException.new("The current path is not part of a git repository.") if !git_dir
    git_dir
  end

  private

  def find_git_dir(start_dir)
    last_dir = nil
    dir = File.expand_path(start_dir)
    while dir != last_dir
      if File.exist?("#{dir}/.git") || dir =~ /\.git$/
        return dir
      end
      last_dir = dir
      # returns itself on file system root
      dir = File.dirname(dir)
    end
    nil
  end

end
end
end


