require File.expand_path("../lib/roda/version", __FILE__)

Gem::Specification.new do |s|
  s.name              = "roda"
  s.version           = Roda::RodaVersion.dup
  s.summary           = "Routing tree web toolkit"
  s.authors           = ["Jeremy Evans"]
  s.email             = ["code@jeremyevans.net"]
  s.homepage          = "https://roda.jeremyevans.net"
  s.license           = "MIT"
  s.required_ruby_version = ">= 2.0"
  s.metadata          = { 
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/roda/issues',
    'changelog_uri'     => 'https://roda.jeremyevans.net/rdoc/files/CHANGELOG.html',
    'documentation_uri' => 'https://roda.jeremyevans.net/documentation.html',
    'mailing_list_uri'  => 'https://github.com/jeremyevans/roda/discussions',
    "source_code_uri"   => "https://github.com/jeremyevans/roda" 
  }

  s.files = %w'MIT-LICENSE' + Dir['lib/**/*.rb']
  s.extra_rdoc_files = %w'MIT-LICENSE'

  s.add_dependency "rack"
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest", ">= 5.7.0"
  s.add_development_dependency "minitest-hooks"
  s.add_development_dependency "minitest-global_expectations"
  s.add_development_dependency "tilt"
  s.add_development_dependency "erubi"
  s.add_development_dependency "rack_csrf"
  s.add_development_dependency "json"
  s.add_development_dependency "mail"
end
