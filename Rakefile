require "rubygems"
require "rake/testtask"
require "rdoc/task"
require "rubygems/package_task"
require "rspec/core/rake_task"
require "bundler/gem_tasks"

spec = Gem::Specification.load(File.join(File.dirname(__FILE__), "threadz.gemspec"))

desc "Default Task"
task "default" => ["spec", "rdoc"]


desc "Run all unit tests"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f n", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/*_spec.rb'
end


namespace "spec" do
  desc "Run all performance-oriented test cases"
  RSpec::Core::RakeTask.new(:performance) do |t|
    t.rspec_opts = ["-c", "-f n", "-r ./spec/spec_helper.rb"]
    t.pattern = 'spec/performance/*_spec.rb'
  end

  desc "Run *all* specs"
  RSpec::Core::RakeTask.new(:all) do |t|
    t.rspec_opts = ["-c", "-f n", "-r ./spec/spec_helper.rb"]
    t.pattern = 'spec/**/*_spec.rb'
  end
end


Rake::RDocTask.new do |rdoc|
  rdoc.main = "README.rdoc"
  rdoc.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rdoc.title = "Threadz Thread Pool"
  rdoc.rdoc_dir = "doc"
end
