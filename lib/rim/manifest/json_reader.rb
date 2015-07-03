require 'json'
require 'csv'
require 'rim/manifest/helper'
require 'rim/manifest/model'

class RimError < StandardError
  def self.status_code(code)
    define_method(:status_code) { code }
  end
end

class ManifestFileNotFound       < RimError; status_code(10) ; end

module RIM
module Manifest


  def read_manifest
    f = Helpers::default_manifest
    raise "no manifest found" unless f
    m = File.read(f)
    data_hash = JSON.parse(m)
    manifest = Manifest.new
    remote = Remote.new(:fetch_url => data_hash["fetch_url"])
    manifest.add_remote(remote)
    modules = data_hash["dependencies"]
    modules.each do |m|
      manifest.add_module(
        Module.new(
          :remote_path => m["remote_path"],
          :local_path => m["destination"],
          :revision => m["version"],
          :remote => remote
        ))
    end
    manifest
  end
end
end

# actual = CSV.read('manifest.lock')
# puts actual.inspect
