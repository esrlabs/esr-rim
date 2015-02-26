$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/file_helper'
require 'fileutils'
require 'test_helper'

include FileUtils

class FileHelperTest < Minitest::Test
  include TestHelper

  def setup
    @test_dir = empty_test_dir("file_helper_test")
  end
  
  def teardown
    remove_test_dirs
  end

  def test_find_matching_relative_files
    create_test_file(".", "aaa")
    create_test_file(".", "abc")
    create_test_file(".", "bbb")
    create_test_file("f1", "aaa")
    create_test_file("f1", "ccc")
    create_test_file("f2", "ccc")
    create_test_file("f2", "ddd")
    files = RIM::FileHelper.find_matching_files(@test_dir, false)
    assert files[0] == "aaa"
    assert files[1] == "abc"
    assert files[2] == "bbb"
    assert files[3] == "f1"
    assert files[4] == "f1/aaa"
    assert files[5] == "f1/ccc"
    assert files[6] == "f2"
    assert files[7] == "f2/ccc"
    assert files[8] == "f2/ddd"
  end

  def test_find_matching_absolute_files
    create_test_file(".", "aaa")
    create_test_file(".", "abc")
    create_test_file(".", "bbb")
    create_test_file("f1", "aaa")
    create_test_file("f1", "ccc")
    create_test_file("f2", "ccc")
    create_test_file("f2", "ddd")
    files = RIM::FileHelper.find_matching_files(@test_dir, true)
    assert files[0] == File.join(@test_dir, "aaa")
    assert files[1] == File.join(@test_dir, "abc")
    assert files[2] == File.join(@test_dir, "bbb")
    assert files[3] == File.join(@test_dir, "f1")
    assert files[4] == File.join(@test_dir, "f1/aaa")
    assert files[5] == File.join(@test_dir, "f1/ccc")
    assert files[6] == File.join(@test_dir, "f2")
    assert files[7] == File.join(@test_dir, "f2/ccc")
    assert files[8] == File.join(@test_dir, "f2/ddd")
  end

  def test_find_matching_relative_files_with_patterns
    create_test_file(".", "aaa")
    create_test_file(".", "abc")
    create_test_file(".", "bbb")
    create_test_file("f1", "aaa")
    create_test_file("f1", "ccc")
    create_test_file("f2", "ccc")
    create_test_file("f2", "ddd")
    files = RIM::FileHelper.find_matching_files(@test_dir, false, ["**/a*", "f2/ccc"])
    assert files[0] == "aaa"
    assert files[1] == "abc"
    assert files[2] == "f1/aaa"
    assert files[3] == "f2/ccc"
  end

  def test_find_matching_absolute_files_with_patterns
    create_test_file(".", "aaa")
    create_test_file(".", "abc")
    create_test_file(".", "bbb")
    create_test_file("f1", "aaa")
    create_test_file("f1", "ccc")
    create_test_file("f2", "ccc")
    create_test_file("f2", "ddd")
    files = RIM::FileHelper.find_matching_files(@test_dir, true, ["**/a*", "f2/ccc"])
    assert files[0] == File.join(@test_dir, "aaa")
    assert files[1] == File.join(@test_dir, "abc")
    assert files[2] == File.join(@test_dir, "f1/aaa")
    assert files[3] == File.join(@test_dir, "f2/ccc")
  end
  
  def test_remove_empty_dirs
    create_test_file(".", "a")
    create_test_file("f1", "ab")
    create_test_file("f1/f1")
    create_test_file("f1/f1/f1")
    create_test_file("f1/f1/f2")
    RIM::FileHelper.remove_empty_dirs(@test_dir)
    files = RIM::FileHelper.find_matching_files(@test_dir, false)
    assert files[0] = "a"
    assert files[1] = "f1"
    assert files[2] = "f1/ab"
  end
    
private
  
  def create_test_file(dir, name = nil)
    abs_dir = File.join(@test_dir, dir)
    FileUtils.mkdir_p(abs_dir)
    if name
      File.open(File.join(abs_dir, name), "w") do |f| 
        f.write("Content of #{name}\n") 
      end
    end
  end
  
end
