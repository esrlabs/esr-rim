$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/module_info'
require 'rim/module_sync_helper'
require 'test_helper'
require 'fileutils'

include FileUtils

class ModuleSyncHelperTest < Minitest::Test
  include TestHelper

  def setup
    test_dir = empty_test_dir("module_sync_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
    @ws_dir = File.join(test_dir, "ws")
    FileUtils.mkdir(@remote_git_dir)
    RIM::git_session(@remote_git_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B testbr")
      File.open(File.join(@remote_git_dir, "readme.txt"), "w") do |f| 
        f.write("Content.") 
      end
      s.execute("git add .")
      s.execute("git commit -m 'Initial commit'")
    end
  end
  
  def teardown
    remove_test_dirs
  end

  def test_files_are_copied_to_working_dir
    info = RIM::ModuleInfo.new(@remote_git_dir, "test", "testbr")
    cut = RIM::ModuleSyncHelper.new(@ws_dir, info)
    cut.sync
    assert File.exists?(File.join(@ws_dir, "test/readme.txt"))
    assert File.exists?(File.join(@ws_dir, "test/.riminfo"))
  end
  
end
