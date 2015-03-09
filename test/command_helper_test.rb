$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'minitest/autorun'
require 'rim/command_helper'
require 'test_helper'
require 'fileutils'

class CommandHelperTest < Minitest::Test
  include FileUtils
  include TestHelper

  def setup
    test_dir = empty_test_dir("command_helper_test")
  end
  
  def teardown
    remove_test_dirs
  end

  def test_get_absolute_remote_url
    cut = RIM::CommandHelper.new(".", nil)
    assert "file:" + File.expand_path(".") == cut.get_absolute_remote_url("file://" + File.expand_path("."))    
    assert "file:" + File.expand_path(".") == cut.get_absolute_remote_url("file:" + File.expand_path("."))    
    assert "file:" + File.expand_path("command_helper_test", ".") == cut.get_absolute_remote_url("file:command_helper_test")
    assert "ssh://gerrit/abcde" == cut.get_absolute_remote_url("abcde")    
    assert "ssh://gerrit2/abcde" == cut.get_absolute_remote_url("ssh://gerrit2/abcde")    
  end
  
end
