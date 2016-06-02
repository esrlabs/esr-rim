module RIM

class ModuleInfo
  # remote url (unique identifier of module)
  attr_reader :remote_url
  # remote branch format
  attr_reader :remote_branch_format
  # locale module path
  attr_reader :local_path
  # target revision
  attr_reader :target_revision
  # ignores
  attr_reader :ignores

  attr_reader :subdir
  
  def initialize(remote_url,
                 local_path,
                 target_revision,
                 ignores = nil,
                 remote_branch_format = nil,
                 subdir = "")
    @remote_url = remote_url
    @remote_branch_format = remote_branch_format
    @local_path = local_path
    @target_revision = target_revision
    @subdir = subdir
    if ignores.is_a?(String)
      @ignores = ignores.split(",").each do |s| 
        s.strip! 
      end 
    else
      @ignores = ignores || []
    end
  end
  
  def valid?
    return @remote_url && @local_path && @target_revision
  end
  
end

end
