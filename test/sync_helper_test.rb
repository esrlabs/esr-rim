$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/module_info'
require 'rim/status_builder'
require 'rim/sync_helper'
require 'test_helper'
require 'fileutils'

class SyncHelperTest < Minitest::Test
  include FileUtils
  include TestHelper

  def setup
    test_dir = empty_test_dir("sync_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
    @ws_remote_dir = File.join(test_dir, "remote_ws")
    @ws_dir = File.join(test_dir, "ws")
    @logger = Logger.new($stdout)
    @logger.level = Logger::ERROR unless ARGV.include? "debug"
    RIM::GitSession.logger = @logger
  end
  
  def teardown
    remove_test_dirs
  end

  def test_files_are_synchronized
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info, mod2_info])
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      assert !File.exist?(File.join(@ws_dir, "mod1"))
      assert !File.exist?(File.join(@ws_dir, "mod2"))
      s.execute("git checkout rim/testbr")
      check_not_dirty(s)
      log = s.execute("git log | grep \" module \"").split("\n").sort
      assert log.size == 2
      assert log[0].include?("mod1")
      assert log[1].include?("mod2")
      assert File.exist?(File.join(@ws_dir, "mod1"))
      assert File.exist?(File.join(@ws_dir, "mod2"))
      assert File.exist?(File.join(@ws_dir, "mod1", "readme.txt"))
      assert File.exist?(File.join(@ws_dir, "mod2", "readme.txt"))
    end
  end

  def test_files_are_synchronized_subtree
    mod_git_dir = create_all_module_git("mod_all")
    mod_a_info =  RIM::ModuleInfo.new("file://" + mod_git_dir, "modules/a", "master", nil, nil, "mod_a")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod_a_info])
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      assert !File.exist?(File.join(@ws_dir, "modules", "a"))
      s.execute("git checkout rim/testbr")
      check_not_dirty(s)
      log = s.execute("git log | grep \" module \"").split("\n").sort
      assert log.size == 1
      assert log[0].include?("modules/a")
      assert !File.exist?(File.join(@ws_dir, "modules", "b"))
      assert File.exist?(File.join(@ws_dir, "modules", "a"))
      assert File.exist?(File.join(@ws_dir, "modules", "a", "file_a.c"))
    end
  end

  def test_files_are_synchronized_subtree_deep
    mod_git_dir = create_all_module_git("mod_all")
    mod_a_info =  RIM::ModuleInfo.new("file://" + mod_git_dir, "modules/b_src", "master", nil, nil, "mod_b/src")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod_a_info])
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      assert !File.exist?(File.join(@ws_dir, "modules", "b_src"))
      s.execute("git checkout rim/testbr")
      check_not_dirty(s)
      log = s.execute("git log | grep \" module \"").split("\n").sort
      assert log.size == 1
      assert log[0].include?("modules/b_src")
      assert File.exist?(File.join(@ws_dir, "modules", "b_src", "file_b.c"))
    end
  end


  def test_files_are_synchronized_on_existing_branch
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info, mod2_info])
    cut.sync
    `echo ' changed' >> #{File.join(@ws_dir, "readme")}`
    RIM::git_session(@ws_dir) do |s|
      s.execute("git commit . -m \"Changed ws file\"")
    end
    remote_path = path_from_module_info(mod1_info)
    `echo ' changed' >> #{File.join(remote_path, "readme.txt")}`
    RIM::git_session(remote_path) do |f|
      f.execute("git commit . -m \"Changed mod1 file\"")
    end
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      s.execute("git checkout rim/testbr")
      check_not_dirty(s)
      log = s.execute("git log | grep \" module \"").split("\n").sort
      assert log.size == 3
      assert log[0].include?("mod1")
      assert log[1].include?("mod1")
      assert log[2].include?("mod2")
      assert File.exist?(File.join(@ws_dir, "mod1"))
      `cat #{File.join(@ws_dir, "mod1/readme.txt")}`.start_with?("Content. changed")
      assert File.exist?(File.join(@ws_dir, "mod2"))
    end
  end
  
  def test_files_are_synchronized_on_new_branch_if_behind_last_remote_commit
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info, mod2_info])
    cut.sync
    `echo ' changed' >> #{File.join(@ws_remote_dir, "readme")}`
    RIM::git_session(@ws_remote_dir) do |s|
      s.execute("git commit . -m \"Changed ws file\"")
    end
    RIM::git_session(@ws_dir) do |s|
      s.execute("git pull")
      assert !has_ancestor?(s, "rim/testbr", "testbr")
    end
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      assert has_ancestor?(s, "rim/testbr", "testbr")
    end
  end
  
  def test_existing_non_ignored_files_are_removed_during_sync
    mod1_info = create_module_git("mod1")
    create_ws_git("testbr") do |s|
      FileUtils.mkdir_p(File.join(@ws_remote_dir, "mod1"))
      File.open(File.join(@ws_remote_dir, "mod1", "existing.txt"), "w") do |f|
        f.write("Content")
      end
      s.execute("git add --all mod1")
      s.execute("git commit -m \"Create existing file within mod1\"")
    end
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info])
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      s.execute("git rebase rim/testbr")
      assert !File.exists?(File.join(@ws_dir, "mod1", "existing.txt"))
    end
  end
  
  def test_case_change_in_filename_is_synced_correctly
    mod1_info = create_module_git("mod1")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info])
    cut.sync
    remote_path = path_from_module_info(mod1_info)
    RIM::git_session(remote_path) do |s|
      FileUtils.mv(File.join(remote_path, "readme.txt"), File.join(remote_path, "readme.tx_"))
      s.execute("git add --all .")
      s.execute("git commit -m \"Temporary change of filename within mod1\"")
      FileUtils.mv(File.join(remote_path, "readme.tx_"), File.join(remote_path, "Readme.txt"))
      s.execute("git add --all .")
      s.execute("git commit -m \"Changed case in filename within mod1\"")
    end
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      s.execute("git rebase rim/testbr")
      out = s.execute("git show --name-only")
      assert out.include?("readme.txt")
      assert out.include?("Readme.txt")
    end
  end

  def test_sync_on_different_branches
    mod1_info = create_module_git("mod1")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, @logger, [mod1_info])
    cut.sync
    remote_path = path_from_module_info(mod1_info)
    RIM::git_session(remote_path) do |s|
      FileUtils.mv(File.join(remote_path, "readme.txt"), File.join(remote_path, "readme.tx_"))
      s.execute("git add --all .")
      s.execute("git commit -m \"Temporary change of filename within mod1\"")
      FileUtils.mv(File.join(remote_path, "readme.tx_"), File.join(remote_path, "Readme.txt"))
      s.execute("git add --all .")
      s.execute("git commit -m \"Changed case in filename within mod1\"")
    end
    RIM::git_session(@ws_dir) do |s|
      s.execute("git checkout -b branch2")
    end
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      s.execute("git rebase rim/branch2")
      out = s.execute("git show --name-only")
      assert out.include?("Readme.txt")
    end
    RIM::git_session(remote_path) do |s|
      `echo ' changed' >> #{File.join(remote_path, "Readme.txt")}`
      s.execute("git commit . -m \"Changed module file\"")
    end
    cut.sync    
    RIM::git_session(@ws_dir) do |s|
      s.execute("git rebase rim/branch2")
      s.execute("git checkout testbr")
      s.execute("git reset --hard branch2~1")
      s.execute("git push origin branch2:branch2")
    end
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      s.execute("git reset --hard rim/testbr")
      out = s.execute("git show --name-only")
      assert out.include?("Readme.txt")
    end
  end

private
  def create_ws_git(branch = "master")
    FileUtils.mkdir_p(@ws_remote_dir)
    RIM::git_session(@ws_remote_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B #{branch}")
      File.open(File.join(@ws_remote_dir, ".gitignore"), "w") do |f| 
        f.write(".rim") 
      end
      File.open(File.join(@ws_remote_dir, "readme"), "w") do |f|
        f.write("Content")
      end
      s.execute("git add .")
      s.execute("git commit -m \"Initial commit\"")
      yield s if block_given?
    end
    FileUtils.mkdir_p(@ws_dir)
    RIM::git_session(@ws_dir) do |s|
      s.execute("git clone #{@ws_remote_dir} #{@ws_dir}")
    end
  end

  def create_module_git(name, branch = "master")
    git_dir = File.join(@remote_git_dir, name)
    FileUtils.mkdir_p(git_dir)
    RIM::git_session(git_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B #{branch}")
      File.open(File.join(git_dir, "readme.txt"), "w") do |f| 
        f.write("Content.") 
      end
      s.execute("git add .")
      s.execute("git commit -m \"Initial commit\"")
    end
    return RIM::ModuleInfo.new("file://" + git_dir, name, branch)
  end

  def create_all_module_git(name, branch = "master")
    git_dir = File.join(@remote_git_dir, name)
    FileUtils.mkdir_p(File.join(git_dir,"mod_a"))
    FileUtils.mkdir_p(File.join(git_dir,"mod_b","src"))
    RIM::git_session(git_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B #{branch}")
      File.open(File.join(git_dir, "readme.txt"), "w") do |f|
        f.write("Content.")
      end
      File.open(File.join(git_dir, "mod_a", "file_a.c"), "w") do |f|
        f.write("Content.")
      end
      File.open(File.join(git_dir, "mod_b", "src", "file_b.c"), "w") do |f|
        f.write("Content.")
      end
      s.execute("git add .")
      s.execute("git commit -m \"Initial commit\"")
    end
    return git_dir
  end

  def path_from_module_info(module_info)
    module_info.remote_url.gsub(/^file:\/\//, "")
  end

  def check_not_dirty(session)
    status = RIM::StatusBuilder.new.rev_status(session, "HEAD")
    status.modules.each do |m|
      assert !m.dirty?
    end    
  end
  
  def has_ancestor?(session, rev, ancestor)
    rev = session.execute("git rev-list #{rev}").include?(session.rev_sha1(ancestor))
  end
  
end
