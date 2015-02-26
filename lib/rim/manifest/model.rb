module RIM
module Manifest

class Manifest

  attr_reader :remote_url
  attr_reader :modules
  
  def initialize(remote_url, modules)
    @remote_url = remote_url
    @modules = modules
  end

end

class Module
  attr_reader :remote_path
  attr_reader :local_path
  attr_reader :target_revision
  attr_reader :ignores

  def initialize(args = {})
    @remote_path = args[:remote_path]
    @local_path = args[:local_path]
    @target_revision = args[:target_revision]
    @ignores = args[:ignores]
  end
end

end

end

