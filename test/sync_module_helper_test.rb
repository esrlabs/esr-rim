$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/dirty_check'
require 'rim/module_info'
require 'rim/sync_module_helper'
require 'test_helper'
require 'fileutils'

class SyncModuleHelperTest < Minitest::Test
  include FileUtils
  include TestHelper

  def setup
    @logger = Logger.new($stdout)
    @logger.level = Logger::ERROR unless ARGV.include? "debug"
    RIM::GitSession.logger = @logger
    test_dir = empty_test_dir("module_sync_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
    @remote_git_dir_url = "file://" + @remote_git_dir
    FileUtils.mkdir(@remote_git_dir)
    RIM::git_session(@remote_git_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B testbr")
      write_file(@remote_git_dir, "readme.txt")
      s.execute("git add .")
      s.execute("git commit -m \"Initial commit\"")
    end
    @ws_dir = File.join(test_dir, "ws")
    FileUtils.mkdir(@ws_dir)
    RIM::git_session(@ws_dir) do |s|
      s.execute("git clone #{@remote_git_dir_url} .")
    end
  end
  
  def teardown
    remove_test_dirs
  end

  def test_files_are_copied_to_working_dir
    info = RIM::ModuleInfo.new(@remote_git_dir_url, "test", "testbr")
    cut = RIM::SyncModuleHelper.new(@ws_dir, @ws_dir, info, @logger)
    cut.sync
    assert File.exists?(File.join(@ws_dir, "test/readme.txt"))
    assert File.exists?(File.join(@ws_dir, "test/.riminfo"))
  end

  def test_files_ignored_by_gitignore_of_workspace_are_copied_to_working_dir
    RIM::git_session(@remote_git_dir) do |s|
      write_file(@remote_git_dir, 'ignored_file.txt')
      s.execute("git add .")
      s.execute("git commit -m \"Add a single file\"")
    end
    RIM::git_session(@ws_dir) do |s|
      write_file(@ws_dir, '.gitignore', 'ignored*\n')
      s.execute("git add .")
      s.execute("git commit -m \"Ignore a single file\"")
    end
    info = RIM::ModuleInfo.new(@remote_git_dir_url, "test", "testbr")
    cut = RIM::SyncModuleHelper.new(@ws_dir, @ws_dir, info, @logger)
    cut.sync
    assert File.exists?(File.join(@ws_dir, "test/readme.txt"))
    assert File.exists?(File.join(@ws_dir, "test/.riminfo"))
    assert File.exists?(File.join(@ws_dir, "test/ignored_file.txt"))
    # Add a single ignored file afterwards and sync again
    RIM::git_session(@remote_git_dir) do |s|
      write_file(@remote_git_dir, 'ignored_file_2.txt')
      s.execute("git add .")
      s.execute("git commit -m \"Add a second ignored file\"")
    end
    cut.sync
    assert File.exists?(File.join(@ws_dir, "test/readme.txt"))
    assert File.exists?(File.join(@ws_dir, "test/.riminfo"))
    assert File.exists?(File.join(@ws_dir, "test/ignored_file.txt"))
    assert File.exists?(File.join(@ws_dir, "test/ignored_file_2.txt"))
  end

  def test_files_of_ignore_list_are_not_removed_when_copying
    test_folder = File.join(@ws_dir, "test")
    write_file(test_folder, "file1")
    write_file(test_folder, "file2")
    write_file(File.join(test_folder, "folder"), "file1")
    write_file(File.join(test_folder, "folder"), "file2")
    write_file(File.join(test_folder, "folder2"), "file1")
    info = RIM::ModuleInfo.new(@remote_git_dir_url, "test", "testbr", nil, "**/file2")
    cut = RIM::SyncModuleHelper.new(@ws_dir, @ws_dir, info, @logger)
    cut.sync
    assert File.exists?(File.join(test_folder, "readme.txt"))
    assert File.exists?(File.join(test_folder, ".riminfo"))
    assert !File.exists?(File.join(test_folder, "file1"))
    assert File.exists?(File.join(test_folder, "file2"))
    assert !File.exists?(File.join(test_folder, "folder/file1"))
    assert File.exists?(File.join(test_folder, "folder/file2"))
    assert File.exists?(File.join(test_folder, "folder/file2"))
  end

  def test_commit_message_is_set_by_default
    info = RIM::ModuleInfo.new(@remote_git_dir_url, "test", "testbr")
    cut = RIM::SyncModuleHelper.new(@ws_dir, @ws_dir, info, @logger)
    cut.sync
    RIM::git_session(@ws_dir) do |s|
      out = s.execute("git log HEAD~1..HEAD")
      assert out.include?("rim sync: module")
    end
  end

  def test_commit_message_can_be_changed
    info = RIM::ModuleInfo.new(@remote_git_dir_url, "test", "testbr")
    cut = RIM::SyncModuleHelper.new(@ws_dir, @ws_dir, info, @logger)
    cut.sync("This is the commit header.")
    RIM::git_session(@ws_dir) do |s|
      out = s.execute("git log HEAD~1..HEAD")
      assert out.include?("This is the commit header.\n")
    end
  end

  def write_file(dir, name, content = nil)
    FileUtils.mkdir_p(dir)
    File.open(File.join(dir, name), "w") do |f| 
      f.write(content || "Content of #{name}\n") 
    end
  end
  
end
