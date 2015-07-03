module RIM
module Manifest

class Manifest
  
  def initialize
    @modules = []
    @remotes = []
  end
  
  def modules
    @modules.dup
  end

  def remotes
    @remotes.dup
  end

  def add_module(m)
    @modules << m
  end

  def add_remote(r)
    @remotes << r
  end

end

class Remote
  attr_reader :fetch_url
  attr_reader :review_url

  def initialize(args={})
    @fetch_url = args[:fetch_url]
    @review_url = args[:review_url]
  end
end

class Module
  attr_reader :local_path
  attr_reader :remote_path
  attr_reader :revision
  attr_reader :remote

  def initialize(args={})
    @local_path = args[:local_path]
    @remote_path = args[:remote_path]
    @revision = args[:revision]
    @remote = args[:remote]
  end

  def remote_url
    url = remote.fetch_url
    url << "/" unless url[-1] == "/"
    url + remote_path
  end

end

end
end

