require 'rubygems'
require 'rake/testtask'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rubygems/source_info_cache'
require 'spec/rake/spectask'
require "bundler/gem_tasks"

spec = Gem::Specification.load(File.join(File.dirname(__FILE__), 'threadz.gemspec'))

desc "Default Task"
task 'default' => ['spec', 'rdoc']


desc "Run all test cases"
task 'spec' do |task|
  exec 'spec -c -f n spec/*.rb spec/basic/*.rb'
end

desc "Run all performance-oriented test cases"
task 'spec:performance' do |task|
  exec 'spec -c -f n -t 30.0 spec/spec_helper.rb spec/performance/*.rb'
end

desc "Run *all* specs"
task 'spec:all' do |task|
  exec 'spec -c -f n -t 30.0 spec/spec_helper.rb spec/**/*.rb'
end

desc "Run all test cases 10 times (or n times)"
task 'spec-stress', [:times] do |task, args|
  args.with_defaults :times => 10
  puts "Executing spec #{args.times} times"
  puts Rake::Task[:spec].methods.sort.inspect
  args.times.times do
    Rake::Task[:spec].execute
    puts "foo"
  end
  puts "Done!"
end

Rake::RDocTask.new do |rdoc|
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'lib/**/*.rb')
  rdoc.title = "Threadz Thread Pool"
  rdoc.rdoc_dir = 'doc'
end
