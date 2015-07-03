$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'fileutils'
require 'test_helper'
require 'rim/rim_info'

class RimInfoTest < MiniTest::Test

include FileUtils
include TestHelper

def test_empty
  d = empty_test_dir("rim_info")
  ri = RIM::RimInfo.from_dir(d)
  assert_nil ri.remote_url
end

def test_write
  d = empty_test_dir("rim_info")
  ri = RIM::RimInfo.new
  ri.remote_url = "ssh://gerrit"
  ri.to_dir(d)
  # some whitebox testing here
  ri_file = d+"/.riminfo"
  assert File.exist?(ri_file)
  assert File.read(ri_file) =~ /remote_url:\s+ssh:\/\/gerrit/
end

def test_read
  d = empty_test_dir("rim_info")
  create_rim_info(d, :remote_url => "ssh://gerrit")
  ri = RIM::RimInfo.from_dir(d)
  assert_equal "ssh://gerrit", ri.remote_url
end

def test_tamper
  d = empty_test_dir("rim_info")
  create_rim_info(d, :remote_url => "ssh://gerrit")
  # before
  ri = RIM::RimInfo.from_dir(d)
  assert_equal "ssh://gerrit", ri.remote_url
  # modify
  File.open(d+"/.riminfo", "a") do |f|
    f.write "one more line\n"
  end
  # after
  ri = RIM::RimInfo.from_dir(d)
  assert_nil ri.remote_url
end

def test_attributes
  attrs = {
    :remote_url => "ssh://somehost/dir1/dir2",
    :revision => "8347982374198379842984562095637243593092",
    :upstream => "trunk",
    :ignores => "CMakeLists.txt,*.arxml"
  }
  d = empty_test_dir("rim_info")
  create_rim_info(d, attrs)
  ri = RIM::RimInfo.from_dir(d)
  #puts File.read(d+"/.riminfo")
  attrs.each_pair do |k,v|
    assert_equal v, ri.send(k)
  end
end

def teardown
  # clean up test dirs created during last test
  remove_test_dirs
end

end

