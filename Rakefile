require "rake"
require "rake/clean"

NAME = 'roda'
VERS = lambda do
  require_relative 'lib/roda/version'
  Roda::RodaVersion
end
CLEAN.include ["#{NAME}-*.gem", "rdoc", "coverage", "www/public/*.html", "www/public/rdoc", "spec/assets/app.*.css", "spec/assets/app.*.js", "spec/assets/app.*.css.gz", "spec/assets/app.*.js.gz", "spec/iv.erb"]

# Gem Packaging and Release

desc "Packages #{NAME}"
task :package=>[:clean] do |p|
  sh %{gem build #{NAME}.gemspec}
end

### RDoc

desc "Generate rdoc"
task :website_rdoc do
  rdoc_dir = "www/public/rdoc"
  rdoc_opts = ["--line-numbers", "--inline-source", '--title', 'Roda: Routing tree web toolkit']

  begin
    gem 'hanna'
    rdoc_opts.concat(['-f', 'hanna'])
  rescue Gem::LoadError
  end

  rdoc_opts.concat(['--main', 'README.rdoc', "-o", rdoc_dir])
  rdoc_opts.concat(%w"README.rdoc CHANGELOG doc/CHANGELOG.old MIT-LICENSE" + Dir["lib/**/*.rb"] + Dir["doc/**/*.rdoc"] + Dir['doc/release_notes/*.txt'])

  FileUtils.rm_rf(rdoc_dir)

  require "rdoc"
  RDoc::RDoc.new.document(rdoc_opts)
end

### Website

desc "Make local version of website"
task :website_base do
  sh %{#{FileUtils::RUBY} -I lib www/make_www.rb}
end

desc "Make local version of website, with rdoc"
task :website => [:website_base, :website_rdoc]

desc "Serve local version of website via rackup"
task :serve => :website do
  sh %{#{FileUtils::RUBY} -C www -S rackup}
end

### Specs

spec = proc do |env|
  env.each{|k,v| ENV[k] = v}
  sh "#{FileUtils::RUBY} #{"-w" if RUBY_VERSION >= '3'} #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} spec/all.rb"
  env.each{|k,v| ENV.delete(k)}
  if File.directory?('.sass-cache')
    require 'fileutils'
    FileUtils.rm_r('.sass-cache')
  end
end

desc "Run specs"
task "spec" do
  spec.call({})
end

task :default=>:spec

desc "Run specs with method visibility checking"
task "spec_vis" do
  spec.call('CHECK_METHOD_VISIBILITY'=>'1')
end
  
desc "Run specs with coverage"
task "spec_cov" do
  spec.call('COVERAGE'=>'< 4')
  spec.call('COVERAGE'=>'< 3.2')
  spec.call('COVERAGE'=>'< 3.1')
  spec.call('COVERAGE'=>'< 3')
  spec.call('COVERAGE'=>'< 1.6', 'RODA_RENDER_COMPILED_METHOD_SUPPORT'=>'no')
end
  
desc "Run specs with Rack::Lint"
task "spec_lint" do
  spec.call('LINT'=>'1')
end
  
desc "Run specs in CI mode"
task "spec_ci" do
  # Use LINT on about half of the tested Ruby versions,
  # rotating each day.
  spec.call(RUBY_VERSION[2].to_i.odd? ^ Time.now.wday.odd? ? {} : {'LINT'=>'1'})
end
  
### Other

desc "Print #{NAME} version"
task :version do
  puts VERS.call
end

desc "Start an IRB shell using the extension"
task :irb do
  require 'rbconfig'
  ruby = ENV['RUBY'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
  irb = ENV['IRB'] || File.join(RbConfig::CONFIG['bindir'], File.basename(ruby).sub('ruby', 'irb'))
  sh %{#{irb} -I lib -r #{NAME}}
end

# Other

desc "Check documentation for plugin files"
task :check_plugin_doc do
  text = File.binread('www/pages/documentation.erb')
  skip = %w'delay_build'
  Dir['lib/roda/plugins/*.rb'].map{|f| File.basename(f).sub('.rb', '') if File.size(f)}.sort.each do |f|
    puts f if !f.start_with?('_') && !skip.include?(f) && !text.include?(">#{f}<")
  end
end
