require 'fileutils'

module TestHelper

def create_rim_info(dir, attrs)
  FileUtils.mkdir_p dir
  ri = RIM::RimInfo.new
  attrs.each_pair do |k,v|
    ri.send("#{k}=", v)
  end
  ri.to_dir(dir)
end

def empty_test_dir(dir)
  # create directory in test folder
  dir = File.dirname(__FILE__)+"/"+dir
  rm_rf(dir)
  mkdir(dir)
  @test_dirs ||= []
  @test_dirs << dir
  dir
end

def write_file(path, content)
  FileUtils.mkdir_p File.dirname(path)
  File.open(path, "w") do |f| 
    f.write content
  end
end

def remove_test_dirs
  @test_dirs ||= []
  @test_dirs.each do |d|
    rm_rf(d)
  end
  @test_dirs = nil
end

end
