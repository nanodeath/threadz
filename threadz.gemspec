# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "threadz/version"

Gem::Specification.new do |s|
  s.name        = "threadz"
  s.version     = Threadz::VERSION
  s.authors     = ["Max Aller"]
  s.email       = ["nanodeath@gmail.com"]
  s.homepage    = "http://github.com/nanodeath/threadz"
  s.summary     = %q{An easy Ruby threadpool library.}
  s.description = %q{A Ruby threadpool library to handle threadpools and make batch jobs easier.}

  s.rubyforge_project = "threadz"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec", "~> 2.12"
end
