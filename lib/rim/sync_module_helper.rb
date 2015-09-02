require 'rim/module_helper'
require 'rim/rim_info'
require 'rim/file_helper'
require 'rim/dirty_check'
require 'tempfile'

module RIM
  class SyncModuleHelper < ModuleHelper
    def initialize(dest_root, workspace_root, module_info, logger)
      super(workspace_root, module_info, logger)
      @dest_root = dest_root
    end

    # do the local sync without committing
    def sync(message = nil)
      fetch_module
      export_module(message)
    end

    private

    # export +revision+ of +mod+ into working copy
    # BEWARE: any changes to the working copy target dir will be lost!
    def export_module(message)
      changes = false
      RIM::git_session(@dest_root) do |d|
        start_sha1 = d.rev_sha1("HEAD")
        git_path = module_git_path(@remote_path)
        RIM::git_session(git_path) do |s|
          if !s.rev_sha1(@module_info.target_revision)
            raise RimException.new("Unknown target revision '#{@module_info.target_revision}' for module '#{@module_info.local_path}'.")
          end
          local_path = File.join(@dest_root, @module_info.local_path)
          prepare_empty_folder(local_path, @module_info.ignores)
          temp_commit(d, "clear directory") if d.uncommited_changes?
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
        temp_commit(d, "commit changes") if needs_commit?(d)
        d.execute("git reset --soft #{start_sha1}")
        changes = d.uncommited_changes?
        commit(d, message || "rim sync: module #{@module_info.local_path}") if changes
      end
      changes
    end

    def needs_commit?(session)
      # do we need to commit something?
      stat = session.status(@module_info.local_path)
      ignored = stat.lines.select{ |l| l.ignored? }
      if ignored.empty?
        session.execute("git add --all #{@module_info.local_path}") do |out, e|
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

    def temp_commit(session, message)
      session.execute("git add --all")
      session.execute("git commit -m \"#{message}\" --")
    end

    def parse_ignored_files(session, out, e)
      first_line = true
      ignored = []
      out.gsub(/warning:.*will be replaced.*\r?\n.*\r?\n/, '').split(/\r?\n/).each do |l|
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
