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
    opts.on("-m", "--manifest [MANIFEST]", String, "Read information from manifest") do |manifest|
      @manifest = manifest ? manifest : Helpers::default_manifest
    end
    opts.on("-c", "--create", "Synchronize module initially to <local_module_path>.", \
                              "Specify the remote URL and the target revision with the options.") do
      @create = true
    end
    @module_options = {}
    opts.on("-r", "--remote-url=URL", String, "Set the remote URL of the module.", \
                                              "A relative path will be applied to ssh://gerrit/") do |url|
      @module_options[:remote_url] = url 
    end
    opts.on("-l", "--local", "If the remote URL is relative this option can be used to indicate", \
                             "that the URL is a local repository relative to working directory") do
      @module_options[:resolve_mode] = :local
    end
    opts.on("-t", "--target-revision=REVISION", String, "Set the target revision of the module.") do |target_revision|
      @module_options[:target_revision] = target_revision
    end
    opts.on("-i", "--ignore=PATTERN_LIST", String, "Set the ignore patterns by specifying a comma separated list.") do |ignores|
      @module_options[:ignores] = ignores
    end
  end

  def invoke()
    helper = SyncHelper.new(project_git_dir, @logger)
    if @manifest
      helper.modules_from_manifest(@manifest)
    elsif @create
      local_path = ARGV.shift || "."
      if RimInfo.exists?(File.join(FileHelper.get_absolute_path(local_path)))
        raise RimException.new("There's already a module file. Don't use the create option to sync the module.")
      elsif !@module_options[:remote_url] || !@module_options[:target_revision]
        raise RimException.new("Please specify remote URL and target revision for the new module.")
      else
        helper.add_module_info(helper.create_module_info(@module_options[:remote_url], @module_options[:local], local_path, @module_options[:target_revision], \
            @module_options[:ignores]))
      end 
    else
      @module_options[:resolve_mode] = :absolute if !@module_options[:remote_url]
      helper.module_from_path(ARGV.shift || ".", @module_options)
    end
    helper.check_arguments
    helper.sync
  end

end

end
end


