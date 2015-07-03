require 'rim/command/command'
require 'rim/processor'
require 'rim/manifest/json_reader'

module RIM
module Command

class Upload < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim upload <local_module_path>+"
    opts.description = "Upload rim modules according to manifest"
  end

  def invoke()
    @processor = Processor.new(".")
    manifest = read_manifest()
    mods = manifest.modules
    @processor.each_module_parallel("updating", mods) do |m, i|
      puts "fetching #{m}..."
      @processor.fetch_module(m)
      tmp_git = @processor.create_tmp_git(m)
      # TODO check that m.revision is really a branch
      @processor.checkout_branch(tmp_git, m.revision)
      @processor.commit_working_copy(tmp_git, m.local_path)
    end
  end

end

end
end


