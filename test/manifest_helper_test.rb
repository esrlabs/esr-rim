$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require "minitest/autorun"
require "rim/manifest/helper"
require "fileutils"

class ManifestHelperTest < Minitest::Test
  include FileUtils
  include RIM::Manifest::Helpers

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
end
