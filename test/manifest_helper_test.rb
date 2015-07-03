$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require "minitest/autorun"
require "rim/manifest/helper"
require "fileutils"

include FileUtils
include RIM::Manifest::Helpers

class ManifestHelperTest < Minitest::Test
  def setup
  end

  def test_find_local_config

    cd File.dirname(__FILE__)+"/manifest_test_dir" do
      m = default_manifest
      assert m != nil
    end
  end

  def test_find_config_from_subdir

    cd File.dirname(__FILE__)+"/manifest_test_dir/subdir" do
      m = default_manifest
      assert m != nil
    end
  end

  def test_that_will_be_skipped
    skip "test this later"
  end
end
