require 'json'
require 'csv'
require 'rim/manifest/model'

class RimError < StandardError
  def self.status_code(code)
    define_method(:status_code) { code }
  end
end

class ManifestFileNotFound       < RimError; status_code(10) ; end

module RIM
module Manifest

  def read_manifest(f)
    raise "no manifest found" unless f
    parse_manifest(File.read(f))
  end
    
  def parse_manifest(json)
    data_hash = JSON.parse(json)
    modules = []
    if data_hash.has_key?("modules")
      data_hash["modules"].each do |mod|
        modules.push(
          Module.new(
            :remote_path => mod["remote_path"],
            :local_path => mod["local_path"],
            :target_revision => mod["target_revision"],
            :ignores => mod["ignores"]
          ))
      end
    end
    Manifest.new(data_hash["remote_url"], modules)
  end

end

end
