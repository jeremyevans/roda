require_relative "../spec_helper"

describe "with_all_directories plugin" do

  it "test all posibile cases" do

    app(:with_all_directories) do |r|
      r.with_all_directories do |dirs|

        r.is do
          "is nil, #{dirs}"
        end

        r.is '' do
          "is empty, #{dirs}"
        end

        r.is 'baz.html' do
          "is baz.html, #{dirs}"
        end

      end

      'should never be reached'
    end

    body('').must_equal 'is nil, '
    body('/').must_equal 'is empty, '
    status('/foo').must_equal 404
    status('/foo/').must_equal 200
    body('/foo/').must_equal 'is empty, foo'
    body('/foo/bar/baz/').must_equal 'is empty, foo/bar/baz'
    status('/foo/bar/baz/').must_equal 200
    status('/foo/bar/baz').must_equal 404
    body('/foo/bar/baz.html').must_equal 'is baz.html, foo/bar'
  end

end
