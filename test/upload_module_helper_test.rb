$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/git'
require 'rim/dirty_check'
require 'rim/module_info'
require 'rim/rim_info'
require 'rim/upload_module_helper'
require 'test_helper'
require 'fileutils'

include FileUtils

class UploadModuleHelperTest < Minitest::Test
  include TestHelper

  def setup
    test_dir = empty_test_dir("upload_module_helper_test")
    @remote_git_dir = File.join(test_dir, "remote_git")
    FileUtils.mkdir(@remote_git_dir)
    RIM::git_session(@remote_git_dir) do |s|
      s.execute("git init")
      s.execute("git checkout -B testbr")
      write_file(@remote_git_dir, "readme.txt")
      s.execute("git add .")
      s.execute("git commit -m 'Initial commit'")
      @initial_rev = s.rev_sha1("HEAD")
    end
    @ws_dir = File.join(test_dir, "ws")
    FileUtils.mkdir(@ws_dir)
    RIM::git_session(@ws_dir) do |s|
      s.execute("git init")
      `echo '.rim' >> #{File.join(@ws_dir, ".gitignore")}`
      s.execute("git checkout -B master")
      write_file(@ws_dir, "initial.txt")
      s.execute("git add .")
      s.execute("git commit -m 'Initial commit'")
      @initial_ws_rev = s.rev_sha1("HEAD")
    end
    @logger = Logger.new($stdout)
  end
  
  def teardown
    remove_test_dirs
  end

  def test_files_are_uploaded_to_branch
    mod_dir = File.join(@ws_dir, "module")
    FileUtils.mkdir_p(mod_dir)
    write_file(mod_dir, "readme.txt")
    rim_info = RIM::RimInfo.new
    rim_info.revision = @initial_rev
    rim_info.upstream = "testbr"
    rim_info.to_dir(mod_dir)
    revs = []
    RIM::git_session(@ws_dir) do |s|
      s.execute("git add --all #{@ws_dir}")
      s.execute("git commit -m 'Initial workspace commit'")
      write_file(@ws_dir, "nomodulefile.txt")
      s.execute("git add --all #{@ws_dir}")
      s.execute("git commit -m 'Added non module file'")
      revs.push(s.rev_sha1("HEAD"))
      write_file(mod_dir, "second.txt")
      s.execute("git add --all #{@ws_dir}")
      s.execute("git commit -m 'Added module file'")
      revs.push(s.rev_sha1("HEAD"))
    end
    info = RIM::ModuleInfo.new(@remote_git_dir, "module", "testbr")
    cut = RIM::UploadModuleHelper.new(@ws_dir, info, @logger)
    cut.upload(nil, revs)
    RIM::git_session(@ws_dir) do |s|
      assert File.exists?(File.join(@ws_dir, "module/readme.txt"))
      assert File.exists?(File.join(@ws_dir, "module/second.txt"))
    end
  end

  def write_file(dir, name)
    FileUtils.mkdir_p(dir)
    File.open(File.join(dir, name), "w") do |f| 
      f.write("Content of #{name}\n") 
    end
  end
  
end
