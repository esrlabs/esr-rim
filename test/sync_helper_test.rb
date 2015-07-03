$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/module_info'
require 'rim/sync_helper'
require 'test_helper'
require 'fileutils'

include FileUtils

class SyncHelperTest < Minitest::Test
  include TestHelper

  def setup
    test_dir = empty_test_dir("sync_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
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
      assert File.exist?(File.join(@ws_dir, ".rim"))
      assert File.exist?(File.join(@ws_dir, "mod1"))
      assert File.exist?(File.join(@ws_dir, "mod2"))
    end
  end
  
private
  def create_ws_git(branch = "master")
    FileUtils.mkdir_p(@ws_dir)
    RIM::git_session(@ws_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B #{branch}")
      File.open(File.join(@ws_dir, ".gitignore"), "w") do |f| 
        f.write(".rim") 
      end
      s.execute("git add .")
      s.execute("git commit -m 'Initial commit'")
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
      s.execute("git commit -m 'Initial commit'")
    end
    return RIM::ModuleInfo.new(git_dir, name, branch)
  end  
  
end
