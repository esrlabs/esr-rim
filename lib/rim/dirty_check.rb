require 'digest'
require 'pathname'
require 'rim/rim_info'
require 'rim/file_helper'

module RIM

# Module dirty state checker.
# 
# Provides means to mark modules as "clean" and check if they become "dirty" later on. 
#
# Once a module has been marked as being clean, it will become dirty if
# any of the following is true:
#
# * Number of contained files has changed
# * File names or location have changed
# * File contents have changed
# * One of the RIM info attributes listed in ChecksumAttributes has changed
# * The RIM info file is missing or became invalid
#
# Ignored files are not considered by this check.
# 
class DirtyCheck

  # raised when there is not enough info for checksum calculation
  class MissingInfoException < Exception
  end

  # attributes to be included into checksum calculation
  # checksum calculation fails if those attributes are not present 
  ChecksumAttributes = [
    :remote_url,
    :revision
  ]

  # rim info must exist in dir and must be valid
  # it also must contain attributes listed in ChecksumAttributes
  # otherwise a MissingInfoException is raised
  def self.mark_clean(dir)
    mi = RimInfo.from_dir(dir)
    cs = self.new.calc_checksum(mi, dir)
    raise MissingInfoException unless cs
    mi.checksum = cs
    mi.to_dir(dir)
  end

  def self.dirty?(dir)
    mi = RimInfo.from_dir(dir)
    # always fails if there is no checksum
    !mi.checksum || mi.checksum != self.new.calc_checksum(mi, dir)
  end

  # returns nil if checksum can't be calculated due to missing info
  def calc_checksum(mi, dir)
    if check_required_attributes(mi)
      sha1 = Digest::SHA1.new
      # all files and directories within dir
      files = FileHelper.find_matching_files(dir, false, "/**/*", File::FNM_DOTMATCH)
      # Dir.glob with FNM_DOTMATCH might return . and ..
      files.delete(".")
      files.delete("..")
      # ignore the info file itself
      files.delete(RimInfo::InfoFileName)
      # ignores defined by user
      files -= FileHelper.find_matching_files(dir, false, mi.ignores)
      # order of files makes a difference
      # sort to eliminate platform specific glob behavior
      files.sort!
      files.each do |fn|
        update_file(sha1, dir, fn)
      end
      ChecksumAttributes.each do |a|
        sha1.update(mi.send(a))
      end
      sha1.hexdigest
    else
      # can't calc checksum
      nil
    end
  end 

  private 

  def ignored_files(mi, dir)
    find_matching_files(dir, mi.ignores)
  end

  def update_file(sha1, dir, filename)
    # file name
    sha1.update(filename)
    fn = dir+"/"+filename
    unless File.directory?(fn)
      # file contents
      sha1.file(fn)
    end
  end

  def check_required_attributes(mi)
    ChecksumAttributes.all?{|a| mi.send(a)}
  end

end

end
