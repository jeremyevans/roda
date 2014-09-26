require File.expand_path("../lib/roda/version", __FILE__)

Gem::Specification.new do |s|
  s.name              = "roda"
  s.version           = Roda::RodaVersion.dup
  s.summary           = "Routing tree web framework"
  s.description       = "Routing tree web framework, inspired by Sinatra and Cuba"
  s.authors           = ["Jeremy Evans"]
  s.email             = ["code@jeremyevans.net"]
  s.homepage          = "https://github.com/jeremyevans/roda"
  s.license           = "MIT"

  s.files = %w'README.rdoc MIT-LICENSE CHANGELOG Rakefile' + Dir['doc/*.rdoc'] + Dir['doc/release_notes/*.txt'] + Dir['{lib,spec}/**/*.rb']
  s.extra_rdoc_files = %w'README.rdoc MIT-LICENSE CHANGELOG' + Dir["doc/*.rdoc"] + Dir['doc/release_notes/*.txt']

  s.add_dependency "rack"
  s.add_development_dependency "rspec"
  s.add_development_dependency "tilt"
  s.add_development_dependency "erubis"
  s.add_development_dependency "rack_csrf"
  s.add_development_dependency "yuicompressor"
end
