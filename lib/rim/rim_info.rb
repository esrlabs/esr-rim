require 'digest'

module RIM

# RimInfo is RIM's per module information written to project gits.
# The user is not meant to modify these files directly:
# Files are protected by a checksum an will become invalid if modified.
#
# Example:
#
#  4759302048574720930432049375757593827561
#  remote_url: ssh://some/url/to/git/repo
#  revision:   8347982374198379842984562095637243593092
#  rev_name:   mymod-1.2.3
#  upstream:   trunk
#  ignores:    CMakeLists.txt,*.arxml
#  checksum:   9584872389474857324485873627894494726222
#
# rev_name is a symbolic name for revision
#
# ignores is a comma separated list of file patterns to be ignored
#
class RimInfo

  InfoFileName = ".riminfo"
  
  AttrsDef = [
    :remote_url,
    :revision_sha1,
    :target_revision,
    :ignores,
    :checksum
  ]

  AttrsDef.each do |d|
    attr_accessor d
  end

  def self.exists?(dir)
    File.exist?(info_file(dir))
  end

  def self.from_dir(dir)
    mi = self.new
    mi.from_dir(dir)
    mi
  end

  def self.from_s(content)
    mi = self.new
    mi.from_s(content)
    mi
  end

  def dirty?
    @dirty
  end

  def from_s(content)
    attrs = {}
    # normalize line endings
    # this way riminfo files will be valid even if line endings are changed
    content = content.gsub("\r\n", "\n")
    checksum = content[0..39]
    # exclude \n after checksum
    content = content[41..-1]
    if content
      content.split("\n").each do |l|
        col = l.index(":")
        if col
          name, value = l[0..col-1], l[col+1..-1]
          if name && value
            attrs[name.strip.to_sym] = value.strip
          end
        end
      end
    end
    AttrsDef.each do |a|
      send("#{a}=".to_sym, attrs[a])
    end
    @dirty = checksum != calc_sha1(content)
  end

  def from_dir(dir)
    file = RimInfo.info_file(dir)
    if File.exist?(file)
      content = nil
      File.open(file, "rb") do |f|
        content = f.read
      end
      from_s(content)
    end
  end

  def to_dir(dir)
    file = RimInfo.info_file(dir)
    content = "\n"
    content << "RIM Info file. You're welcome to read but don't write it.\n"
    content << "Instead, use RIM commands to do the things you want to do.\n"
    content << "BEWARE: Any manual modification will invalidate the file!\n"
    content << "\n"
    content << "#{to_s}\n"
    File.open(file, "wb") do |f|
      f.write(calc_sha1(content)+"\n")
      f.write(content)
    end
  end

  def to_s
    max_len = AttrsDef.collect{|a| a.size}.max
    AttrsDef.collect { |a|
      "#{a.to_s.ljust(max_len)}: #{send(a)}"
    }.join("\n")
  end

  private

  def calc_sha1(content)
    sha1 = Digest::SHA1.new
    sha1.update(content)
    sha1.hexdigest
  end

  def self.info_file(dir)
    dir + "/" + InfoFileName
  end

end

end

