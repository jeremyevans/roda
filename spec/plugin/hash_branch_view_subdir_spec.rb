require_relative "../spec_helper"

begin
  require 'tilt/erb'
rescue LoadError
  warn "tilt not installed, skipping hash_branch_view_subdir test"  
else
describe "hash_branch_view_subdir plugin" do 
  before do
    app(:bare) do
      plugin :render, :views=>'spec/views', :layout=>'./layout-yield'
      plugin :hash_branch_view_subdir

      hash_branch 'about' do |_|
        view 'comp_test'
      end

      route do |r|
        r.hash_branches
        view 'comp_test'
      end
    end
  end

  it "supports appending view subdirectories for each successful hash branch" do
    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    body('/foo').gsub(/\s+/, '').must_equal "HeaderctFooter"
  end

  it "supports removing already configured branches" do
    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    body('/foo').gsub(/\s+/, '').must_equal "HeaderctFooter"
    2.times do
      app.hash_branch 'about'
      body('/about').gsub(/\s+/, '').must_equal "HeaderctFooter"
    end
  end

  it "supports use in subclasses" do
    sub_app = Class.new(app)
    sub_app.hash_branch('about') do |_|
      'a'
    end
    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    @app = sub_app
    body('/about').must_equal 'a'

    sub_app.hash_branch('about') do |_|
      view 'comp_test'
    end
    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
  end

  it "doesn't allow modifications after freezing" do
    app.freeze
    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    body('/foo').gsub(/\s+/, '').must_equal "HeaderctFooter"
    proc{app.hash_branch('about')}.must_raise
  end
end

describe "hash_branch_view_subdir plugin" do 
  it "supports appending view subdirectories for each successful hash branch" do
    app(:bare) do
      plugin :render, :views=>'.', :layout=>'spec/views/layout-yield'
      plugin :hash_branch_view_subdir

      hash_branch 'spec' do |r|
        r.hash_branches('spec')
      end
      hash_branch 'spec', 'views' do |r|
        r.hash_branches('spec_views')
        view 'comp_test'
      end
      hash_branch 'spec_views',  'about' do |_|
        view 'comp_test'
      end

      route do |r|
        r.hash_branches
      end
    end

    body('/spec/views/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    body('/spec/views/foo').gsub(/\s+/, '').must_equal "HeaderctFooter"
  end

  it "works with route_block_args plugin" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :layout=>'./layout-yield'
      plugin :hash_branch_view_subdir

      plugin :route_block_args do
        [request, response]
      end

      hash_branch 'about' do |_, res|
        res.write(view 'comp_test')
      end

      route do |r, _|
        r.hash_branches
        view 'comp_test'
      end
    end

    body('/about').gsub(/\s+/, '').must_equal "Headerabout-ctFooter"
    body('/foo').gsub(/\s+/, '').must_equal "HeaderctFooter"
  end
end
end
