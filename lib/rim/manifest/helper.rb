require 'monitor'
require 'pathname'

module RIM
module Manifest

class RimError < StandardError
  def self.status_code(code)
    define_method(:status_code) { code }
  end
end

class ManifestFileNotFound       < RimError; status_code(10) ; end

module Helpers
  CHDIR_MONITOR = Monitor.new
  CONFIG_FILE_NAME = "manifest.rim"

  def default_manifest
    manifest = find_manifest
    raise ManifestFileNotFound, "Could not locate #{CONFIG_FILE_NAME}" unless manifest
    Pathname.new(manifest)
  end

  def default_lockfile
    manifest = default_manifest
    Pathname.new(manifest.sub(/.rim$/, '.locked'))
  end

  def in_rim_project?
    find_manifest
  end

  def chdir_monitor
    CHDIR_MONITOR
  end

  def chdir(dir, &blk)
    chdir_monitor.synchronize do
      Dir.chdir dir, &blk
    end
  end

private

  def find_manifest
    given = ENV['RIM_MANIFEST']
    return given if given && !given.empty?

    find_file(CONFIG_FILE_NAME)
  end

  def find_file(*names)
    search_up(*names) {|filename|
      return filename if File.file?(filename)
    }
  end

  def find_directory(*names)
    search_up(*names) do |dirname|
      return dirname if File.directory?(dirname)
    end
  end

  def search_up(*names)
    previous = nil
    current  = File.expand_path(Dir.pwd)

    until !File.directory?(current) || current == previous
      names.each do |name|
        filename = File.join(current, name)
        yield filename
      end
      current, previous = File.expand_path("..", current), current
    end
  end
  extend self
end

end # Manifest
end # RIM

