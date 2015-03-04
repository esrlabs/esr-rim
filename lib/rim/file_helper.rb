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
  
  def self.remove_empty_dirs(dir)
    Dir.glob(File.join(dir, "/*/**/")).reverse_each do |d| 
      Dir.rmdir d if Dir.entries(d).size == 2
    end
  end
  
private
  
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
