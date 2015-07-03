require 'nokogiri'
require 'rim/manifest/model'

module RIM
module Manifest

# Reader for the original Google Repo manifest
class RepoReader

def read(file)
  manifest = Manifest.new
  File.open(file) do |f|
    doc = Nokogiri::XML::Document.parse(f)
    remote_by_name = {}
    defaults = nil
    doc.xpath("/manifest/default").each do |d|
      raise "duplicate default setting" if defaults
      defaults = {
        :revision => d.attr("revision"),
        :remote => d.attr("remote")
      }
    end
    doc.xpath("/manifest/remote").each do |r|
      name = r.attr("name")
      raise "remote without a name" unless name
      rem = Remote.new(
        :fetch_url => r.attr("fetch"),
        :review_url => r.attr("review")
        )
      raise "conflicting remote name #{name}" if remote_by_name[name]
      remote_by_name[name] = rem
    end
    doc.xpath("/manifest/project").each do |p|
      remote = p.attr("remote")
      remote ||= defaults[:remote]
      if remote
        raise "remote #{remote} not found" unless remote_by_name[remote]
      else
        raise "no remote specified and no default remote either"
      end
      revision = p.attr("revision")
      revision ||= defaults[:revision]
      if !revision
        raise "no revision specified and no default revision either"
      end
      mod = Module.new(
        :remote_path => p.attr("name"),
        :local_path => p.attr("path"),
        :revision => revision,
        :remote => remote_by_name[remote]
        )
      manifest.add_module(mod)
    end
  end
  manifest
end

end

end
end
