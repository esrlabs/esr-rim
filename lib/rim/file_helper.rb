require 'pathname'
require 'fileutils'

module RIM

class FileHelper

  def self.get_relative_path(path, base)
    Pathname.new(get_absolute_path(path)).relative_path_from(Pathname.new(base)).to_s    
  end
  
  def self.get_absolute_path(path)
    File.expand_path(path)
  end

  def self.find_matching_files(dir, absolute = true, patterns = "**/*", flags = 0)
    files = []
    dirpath = Pathname.new(dir)
    normalize_patterns(patterns).each do |i|
      Dir.glob(File.join(dir, i), flags) do |f|
        if absolute
          files.push(f)
        else
          files.push(Pathname.new(f).relative_path_from(dirpath).to_s)
        end
      end
    end
    files.sort.uniq
  end
  
  def self.find_empty_dirs(dir, exclude = ".")
    exclude = File.join(File.expand_path(exclude), "") if exclude
    dirs = []
    Dir.glob(File.join(dir, "/*/**/")).reverse_each do |d|
      if Dir.entries(d).size == 2 && (!exclude || !exclude.start_with?(d))
        dirs << d
      end
    end
    dirs
  end
  
    def self.remove_empty_dirs(dir, exclude = ".")
    find_empty_dirs(dir, exclude).each do |d|
      Dir.rmdir(d)
    end
  end
  
  def self.make_empty_dir(dir)
    FileUtils.rm_rf dir
    FileUtils.mkdir_p(dir)
  end
  
  def self.normalize_patterns(patterns = [])
    if patterns.is_a?(String)
      return patterns.split(",").each do |p|
        p.strip!       
      end
    elsif !patterns
      patterns = []
    end
    patterns
  end

end

end
