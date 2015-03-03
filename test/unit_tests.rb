$:.unshift File.join(File.dirname(__FILE__))

# include all unit tests here
require 'manifest_helper_test'
require 'file_helper_test'
require 'rim_info_test'
require 'dirty_check_test'
require 'status_builder_test'
require 'sync_module_helper_test'
require 'sync_helper_test'
require 'upload_module_helper_test'
require 'upload_helper_test'
