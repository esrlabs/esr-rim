require 'rake/clean'

desc 'run unit tests'
task :run_tests do
  sh "ruby test/unit_tests.rb"
end

task :default => :run_tests
