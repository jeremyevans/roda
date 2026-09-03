require_relative "../spec_helper"

describe "optimized_segment_matchers plugin" do 
  it "should support on_segment and is_segment match methods" do
    app(:optimized_segment_matchers) do |r|
      r.on_segment do |a|
        r.is_segment do |b|
          "x-#{a}-#{b}"
        end

        "y-#{a}"
      end

      "r"
    end

    unless_lint do
      body('a').must_equal 'r'
    end
    body.must_equal 'r'
    body('//').must_equal 'r'
    body('/a').must_equal 'y-a'
    body('/a/').must_equal 'y-a'
    body('/b').must_equal 'y-b'
    body('/b/').must_equal 'y-b'
    body('/a/b').must_equal 'x-a-b'
    body('/b/a').must_equal 'x-b-a'
    body('/a/b/').must_equal 'y-a'
    body('/a/b/c').must_equal 'y-a'
    body('/a/b/c/').must_equal 'y-a'
  end
end
