spec = Gem::Specification.new do |spec|
  spec.name = 'threadz'
  spec.version = '0.1'
  spec.summary = "Threadz Thread Pool"
  spec.description = <<-EOF
Threadz is a thread pool library that makes it easy to queue up jobs, and wait on
queued up jobs.
EOF

  spec.authors << 'Max Aller'
  spec.email = 'nanodeath@gmail.com'
  spec.homepage = 'http://github.com/nanodeath/threadz'
#  spec.rubyforge_project = ''

  spec.files = Dir['{bin,test,lib}/**/*', 'README.rdoc', 'MIT-LICENSE', 'Rakefile']
  spec.has_rdoc = true
  spec.rdoc_options << '--main' << 'README.rdoc' << '--title' <<  'Threadz Thread Pool' << '--line-numbers'
  spec.extra_rdoc_files = ['README.rdoc', 'MIT-LICENSE']

#  spec.add_dependency 'macaddr', ['~>1.0']
end
