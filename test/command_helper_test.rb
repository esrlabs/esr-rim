$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/command_helper'
require 'test_helper'
require 'fileutils'
require 'json'

class CommandHelperTest < Minitest::Test
  include FileUtils
  include TestHelper

  class TestCommand < RIM::CommandHelper
    
    attr_reader :module_infos
    
    def initialize(*args)
      super
      @module_infos = []
    end
    
    def add_module_info(module_info)
      @module_infos << module_info
    end
    
  end

  def setup
    @test_dir = empty_test_dir("command_helper_test")
    @ws_dir = File.join(@test_dir, "ws")
    @logger = Logger.new($stdout)
    @logger.level = Logger::ERROR unless ARGV.include? "debug"
    RIM::GitSession.logger = @logger
  end
  
  def teardown
    remove_test_dirs
  end

  def test_create_module_info
    cut = RIM::CommandHelper.new(@ws_dir, @logger)
    mi = cut.create_module_info('ssh://gerrit/bsw/test', File.join(@ws_dir, 'sub/test'), 'master', ['CMakeLists.txt', 'OtherPattern*'], 'subdir')
    assert(mi.remote_url == 'ssh://gerrit/bsw/test')
    assert(mi.remote_branch_format == 'refs/for/%s')
    assert(mi.local_path == 'sub/test')
    assert(mi.target_revision == 'master')
    assert(mi.ignores == ['CMakeLists.txt', 'OtherPattern*'])
    assert(mi.subdir == 'subdir')
  end

  def test_modules_from_manifest
    manifest = {
      'modules' => [
        { 'remote_path' => 'ssh://gerrit/bsw/test', 'local_path' => File.join(@ws_dir, 'sub/test'), 'target_revision' => 'master', 'ignores' => ['CMakeLists.txt', 'OtherPattern*'], 'subdir' => 'test/subdir'},
        { 'remote_path' => '../file/test', 'local_path' => File.join(@ws_dir, 'sub/file_test'), 'target_revision' => 'branch' }
      ]
    }
    
    manifest_file = File.join(@test_dir, 'manifest.json')
    File.open(manifest_file, 'w') do |file|
      file << manifest.to_json
    end
    cut = TestCommand.new(@ws_dir, @logger)
    cut.modules_from_manifest(manifest_file)
    assert(cut.module_infos.size == 2)
    mi = cut.module_infos[0]
    assert(mi.remote_url == 'ssh://gerrit/bsw/test')
    assert(mi.remote_branch_format == 'refs/for/%s')
    assert(mi.local_path == 'sub/test')
    assert(mi.target_revision == 'master')
    assert(mi.ignores == ['CMakeLists.txt', 'OtherPattern*'])
    assert(mi.subdir == 'test/subdir')
    mi = cut.module_infos[1]
    assert(mi.remote_url == '../file/test')
    assert(mi.remote_branch_format == 'refs/for/%s')
    assert(mi.local_path == 'sub/file_test')
    assert(mi.target_revision == 'branch')
    assert(mi.ignores == [])
    assert(mi.subdir.nil?)
  end
  
end
