# Adapted from the rake Rakefile.

require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rubygems/source_info_cache'
require 'spec/rake/spectask'


spec = Gem::Specification.load(File.join(File.dirname(__FILE__), 'threadz.gemspec'))

desc "Default Task"
task 'default' => ['spec', 'rdoc']


desc "If you're building from sources, run this task first to setup the necessary dependencies"
task 'setup' do
  windows = Config::CONFIG['host_os'] =~ /windows|cygwin|bccwin|cygwin|djgpp|mingw|mswin|wince/i
  rb_bin = File.expand_path(Config::CONFIG['ruby_install_name'], Config::CONFIG['bindir'])
  spec.dependencies.select { |dep| Gem::SourceIndex.from_installed_gems.search(dep).empty? }.each do |missing|
    dep = Gem::Dependency.new(missing.name, missing.version_requirements)
    spec = Gem::SourceInfoCache.search(dep, true, true).last
    fail "#{dep} not found in local or remote repository!" unless spec
    puts "Installing #{spec.full_name} ..."
    args = [rb_bin, '-S', 'gem', 'install', spec.name, '-v', spec.version.to_s]
    args.unshift('sudo') unless windows || ENV['GEM_HOME']
    sh args.map{ |a| a.inspect }.join(' ')
  end
end


desc "Run all test cases"
task 'spec' do |task|
  exec 'spec -c spec/*.rb'
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

# Create the documentation.
Rake::RDocTask.new do |rdoc|
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'lib/**/*.rb')
  rdoc.title = "Threadz Thread Pool"
  rdoc.rdoc_dir = 'doc'
end


gem = Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

desc "Install the package locally"
task 'install'=>['setup', 'package'] do |task|
  rb_bin = File.expand_path(Config::CONFIG['ruby_install_name'], Config::CONFIG['bindir'])
  args = [rb_bin, '-S', 'gem', 'install', "pkg/#{spec.name}-#{spec.version}.gem"]
  windows = Config::CONFIG['host_os'] =~ /windows|cygwin|bccwin|cygwin|djgpp|mingw|mswin|wince/i
  args.unshift('sudo') unless windows || ENV['GEM_HOME']
  sh args.map{ |a| a.inspect }.join(' ')
end

desc "Uninstall previously installed packaged"
task 'uninstall' do |task|
  rb_bin = File.expand_path(Config::CONFIG['ruby_install_name'], Config::CONFIG['bindir'])
  args = [rb_bin, '-S', 'gem', 'install', spec.name, '-v', spec.version.to_s]
  windows = Config::CONFIG['host_os'] =~ /windows|cygwin|bccwin|cygwin|djgpp|mingw|mswin|wince/i
  args.unshift('sudo') unless windows || ENV['GEM_HOME']
  sh args.map{ |a| a.inspect }.join(' ')
end


task 'release'=>['setup', 'test', 'package'] do

  require 'rubyforge'
  changes = File.read('CHANGELOG')[/\d+.\d+.\d+.*\n((:?^[^\n]+\n)*)/]
  File.open '.changes', 'w' do |file|
    file.write changes
  end

  puts "Uploading #{spec.name} #{spec.version}"
  files = Dir['pkg/*.{gem,tgz,zip}']
  rubyforge = RubyForge.new
  rubyforge.configure
  rubyforge.login
  rubyforge.userconfig.merge! 'release_changes'=>'.changes', 'preformatted'=>true
  rubyforge.add_release spec.rubyforge_project.downcase, spec.name.downcase, spec.version.to_s, *files
  rm_f '.changes'
  puts "Release #{spec.version} uploaded"
end

task 'clobber' do
  rm_f '.changes'
end

desc "Run all examples with RCov"
Spec::Rake::SpecTask.new('spec:rcov') do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "threadz"
    gemspec.summary = "A Ruby threadpool library to handle threadpools and make batch jobs easier."
    #gemspec.description = "Longer description?"
    gemspec.email = "nanodeath@gmail.com"
    gemspec.homepage = "http://github.com/nanodeath/threadz"
    gemspec.authors = ["Max Aller"]
  end
rescue LoadError
  puts "Jeweler not available.  Install it with: sudo gem install jeweler"
end