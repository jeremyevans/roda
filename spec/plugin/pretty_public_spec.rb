require_relative "../spec_helper"

describe "public plugin" do 
  it "allows pretty URLs for HTML files" do
    app(:bare) do
      plugin :pretty_public, :root=>'spec/views'

      route do |r|
        r.pretty_public
      end
    end

    body('/pretty/file').must_equal File.read('spec/views/pretty/file.html')
    body('/pretty/file/').must_equal File.read('spec/views/pretty/file.html')
    body('/pretty/second_file').must_equal File.read('spec/views/pretty/second_file/index.html')
    body('/pretty/second_file/').must_equal File.read('spec/views/pretty/second_file/index.html')
    body('/pretty/third_file').must_equal File.read('spec/views/pretty/third_file/index.html')
    body('/pretty/third_file.html').must_equal File.read('spec/views/pretty/third_file.html')
  end

  it "works with nested routes" do
    app(:bare) do
      plugin :pretty_public, :root=>'spec/views'

      route do |r|
        r.pretty_public

        r.on 'static' do
          r.pretty_public
        end
      end
    end

    body('/pretty/file').must_equal File.read('spec/views/pretty/file.html')
    body('/static/pretty/file').must_equal File.read('spec/views/pretty/file.html')
  end

  it "can check multiple extensions" do
    app(:bare) do
      plugin :pretty_public, :root=>'spec/views', :extensions=>[:html, "htm"]

      route do |r|
        r.pretty_public
      end
    end

    body('/pretty/file').must_equal File.read('spec/views/pretty/file.html')
    body('/pretty/extra').must_equal File.read('spec/views/pretty/extra.htm')
    body('/pretty/second_file').must_equal File.read('spec/views/pretty/second_file/index.html')
    body('/pretty/htm_ext').must_equal File.read('spec/views/pretty/htm_ext/index.htm')
  end

  it "can prioritize files over index folders" do
    app(:bare) do
      plugin :pretty_public, :root=>'spec/views', file_before_folder: true

      route do |r|
        r.pretty_public
      end
    end

    body('/pretty/file').must_equal File.read('spec/views/pretty/file.html')
    body('/pretty/file/').must_equal File.read('spec/views/pretty/file.html')
    body('/pretty/second_file').must_equal File.read('spec/views/pretty/second_file/index.html')
    body('/pretty/second_file/').must_equal File.read('spec/views/pretty/second_file/index.html')
    body('/pretty/third_file').must_equal File.read('spec/views/pretty/third_file.html')
    body('/pretty/third_file/index').must_equal File.read('spec/views/pretty/third_file/index.html')
  end
end
