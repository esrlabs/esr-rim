$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/module_info'
require 'rim/status_builder'
require 'rim/sync_helper'
require 'test_helper'
require 'fileutils'

include FileUtils

class SyncHelperTest < Minitest::Test
  include TestHelper

  def setup
    test_dir = empty_test_dir("sync_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
    @ws_remote_dir = File.join(test_dir, "remote_ws")
    @ws_dir = File.join(test_dir, "ws")
  end
  
  def teardown
    remove_test_dirs
  end

  def test_files_are_synchronized
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, [mod1_info, mod2_info])
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
      assert File.exist?(File.join(@ws_dir, ".rim"))
      assert File.exist?(File.join(@ws_dir, "mod1"))
      assert File.exist?(File.join(@ws_dir, "mod2"))
    end
  end

  def test_files_are_synchronized_on_existing_branch
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, [mod1_info, mod2_info])
    cut.sync
    `echo ' changed' >> #{File.join(@ws_dir, "readme")}`
    RIM::git_session(@ws_dir) do |s|
      s.execute("git commit . -m 'Changed ws file'")
    end
    `echo ' changed' >> #{File.join(mod1_info.remote_url, "readme.txt")}`
    RIM::git_session(mod1_info.remote_url) do |f|
      f.execute("git commit . -m 'Changed mod1 file'")
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
      assert File.exist?(File.join(@ws_dir, ".rim"))
      assert File.exist?(File.join(@ws_dir, "mod1"))
      `cat #{File.join(@ws_dir, "mod1/readme.txt")}`.start_with?("Content. changed")
      assert File.exist?(File.join(@ws_dir, "mod2"))
    end
  end
  
  def test_files_are_synchronized_on_new_branch_if_behind_last_remote_commit
    mod1_info = create_module_git("mod1")
    mod2_info = create_module_git("mod2")
    create_ws_git("testbr")
    cut = RIM::SyncHelper.new(@ws_dir, [mod1_info, mod2_info])
    cut.sync
    `echo ' changed' >> #{File.join(@ws_remote_dir, "readme")}`
    RIM::git_session(@ws_remote_dir) do |s|
      s.execute("git commit . -m 'Changed ws file'")
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
      s.execute("git commit -m 'Initial commit'")
    end
    `git clone #{@ws_remote_dir} #{@ws_dir}`
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
      s.execute("git commit -m 'Initial commit'")
    end
    return RIM::ModuleInfo.new(git_dir, name, branch)
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
