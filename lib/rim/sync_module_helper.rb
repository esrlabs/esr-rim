require 'rim/module_helper'
require 'rim/rim_info'
require 'rim/file_helper'
require 'rim/dirty_check'
require 'tempfile'

module RIM
  class SyncModuleHelper < ModuleHelper
    def initialize(workspace_root, module_info, logger)
      super(workspace_root, module_info, logger)
    end

    # do the local sync without committing
    def sync
      fetch_module
      export_module
    end

    def commit
      RIM::git_session(@ws_root) do |s|
        if needs_commit?(s)
          msg_file = Tempfile.new('message')
          begin
            msg_file << "rim sync: module #{@module_info.local_path}\n\n"
            msg_file << "remote_url: #{@rim_info.remote_url}\n"
            msg_file << "target_revision: #{@rim_info.target_revision}\n"
            msg_file << "revision_sha1: #{@rim_info.revision_sha1}\n"
            msg_file << "ignores: #{@rim_info.ignores}\n"
            msg_file.close
            # add before commit because the path can be below a not yet added path
            s.execute("git add --ignore-removal #{@module_info.local_path}")
            s.execute("git commit #{@module_info.local_path} -F #{msg_file.path}")
          ensure
            msg_file.close(true)
          end
        end
      end
    end

    private

    # export +revision+ of +mod+ into working copy
    # BEWARE: any changes to the working copy target dir will be lost!
    def export_module
      git_path = module_git_path(@remote_path)
      RIM::git_session(git_path) do |s|
        if !s.rev_sha1(@module_info.target_revision)
          raise RimException.new("Unknown target revision '#{@module_info.target_revision}' for module '#{@module_info.local_path}'.")
        end
        local_path = File.join(@ws_root, @module_info.local_path)
        prepare_empty_folder(local_path, @module_info.ignores)
        s.execute("git archive --format tar #{@module_info.target_revision} | tar -x -C #{local_path}")
        sha1 = s.execute("git rev-parse #{@module_info.target_revision}").strip
        @rim_info = RimInfo.new
        @rim_info.remote_url = @module_info.remote_url
        @rim_info.target_revision = @module_info.target_revision
        @rim_info.revision_sha1 = sha1
        @rim_info.ignores = @module_info.ignores.join(",")
        @rim_info.to_dir(local_path)
        DirtyCheck.mark_clean(local_path)
      end
    end

    def needs_commit?(session)
      # do we need to commit something?
      stat = session.status(@module_info.local_path)
      ignored = stat.lines.select{ |l| l.ignored? }
      if ignored.empty?
        session.execute("git add --ignore-removal #{@module_info.local_path}") do |out, e|
          ignored = parse_ignored_files(session, out, e)
        end
        if ignored.empty?
          stat = session.status(@module_info.local_path)
          ignored = stat.lines.select{ |l| l.ignored? }
        end
      end
      if !ignored.empty?
        messages = ["Sync failed due to files/dirs of #{@module_info.local_path} which are ignored by workspace's .gitignore:"]
        ignored.each do |l|
          messages.push(l.file)
        end
        raise RimException.new(messages)
      end
      stat.lines.any?      
    end

    def parse_ignored_files(session, out, e)
      first_line = true
      ignored = []
      out.split(/\r?\n/).each do |l|
        raise e || RimException.new("Cannot parse ignored files after git add:\n#{out}") if first_line && !l.include?(".gitignore")
        if File.exist?(File.expand_path(l, session.execute_dir))
          ignored_line = GitSession::Status::Line.new
          ignored_line.file = l
          ignored_line.istat = "!"
          ignored.push(ignored_line)
        end
        first_line = false
      end
      ignored
    end

  end

end
