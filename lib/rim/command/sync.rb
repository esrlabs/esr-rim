require 'rim/command/command'
require 'rim/manifest/helper'
require 'rim/rim_exception'
require 'rim/rim_info'
require 'rim/sync_helper'
require 'uri'

module RIM
module Command

class Sync < Command

  include RIM::Manifest

  def initialize(opts)
    opts.banner = "Usage: rim sync [<options>] [<local_module_path>]"
    opts.description = "Synchronize specified rim modules with remote repository revisions."
    opts.separator ""
    opts.on("-m", "--manifest [MANIFEST]", String, "Read information from manifest.", \
                                                   "If no manifest file is specified a 'manifest.rim' file will be used.") do |manifest|
      @manifest = manifest ? manifest : Helpers::default_manifest
    end
    opts.on("-c", "--create", "Synchronize module initially to <local_module_path>.", \
                              "Specify the remote URL and the target revision with the options.") do
      @create = true
    end
    opts.on("-a", "--all", "Collects all modules from the specified paths.") do
      @all = true
    end
    opts.on("-e", "--exclude=[PATTERN_LIST]", String, "Exclude all modules of a comma separated list of directories when using sync with -a option.") do |dirlist|
      @excludedirs = dirlist.split(",")
    end
    @module_options = {}
    opts.on("-u", "--remote-url URL", String, "Set the remote URL of the module.", \
                                              "A relative path will be applied to ssh://gerrit/") do |url|
      @module_options[:remote_url] = url 
    end 
    opts.on("-r", "--target-revision REVISION", String, "Set the target revision of the module.") do |target_revision|
      @module_options[:target_revision] = target_revision
    end
    opts.on("-i", "--ignore=[PATTERN_LIST]", String, "Set the ignore patterns by specifying a comma separated list.") do |ignores|
      @module_options[:ignores] = ignores || ""
    end
    opts.on("-m", "--message MESSAGE", String, "Message header to provide to each commit.") do |message|
      @message = message
    end
    opts.on("-s", "--split", "Create a separate commit for each module.") do
      @split = true
    end
    opts.on("-b", "--rebase", "Rebase after successful sync.") do
      @rebase = true
    end
  end

  def invoke()
    helper = SyncHelper.new(project_git_dir, @logger)
    if @manifest
      helper.modules_from_manifest(@manifest)
    elsif @create
      local_path = ARGV.shift || "."
      if helper.find_file_dir_in_workspace(local_path, RimInfo::InfoFileName)
        raise RimException.new("There's already a module file. Don't use the create option to sync the module.")
      elsif !@module_options[:remote_url] || !@module_options[:target_revision]
        raise RimException.new("Please specify remote URL and target revision for the new module.")
      else
        helper.add_module_info(helper.create_module_info(@module_options[:remote_url], local_path, @module_options[:target_revision], \
            @module_options[:ignores]))
      end 
    else
      helper.modules_from_paths(@all ? helper.module_paths(ARGV, @excludedirs) : ARGV, @module_options)
    end
    helper.check_arguments
    helper.sync(@message, @rebase, @split)
  end

end

end
end


