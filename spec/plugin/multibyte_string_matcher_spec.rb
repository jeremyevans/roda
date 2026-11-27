require_relative "../spec_helper"

describe "multibyte_string_matcher plugin" do 
  it "uses multibyte safe string matching" do
    str = "\xD0\xB8".dup.force_encoding('UTF-8')
    app(:unescape_path) do |r|
      r.is String do |s|
        s
      end

      r.is(Integer, /(#{str})/u) do |_, a|
        "#{a}.#{a.encoding}"
      end

      r.is(Integer, Integer, str) do
        'm'
      end

      r.is(Integer, str, Integer) do
        'n'
      end
    end

    body('/%D0%B8').must_equal str
    body('/1/%D0%B8').must_equal "#{str}.UTF-8"
    status('/1/%D0%B82').must_equal 404
    status('/1/2/%D0%B8').must_equal 404
    status('/1/%D0%B8/2').must_equal 404

    status('/1/%D0%B9').must_equal 404
    status('/1/2/%D0%B9').must_equal 404
    status('/1/%D0%B9/2').must_equal 404

    @app.plugin :multibyte_string_matcher

    body('/%D0%B8').must_equal str
    body('/1/%D0%B8').must_equal "#{str}.UTF-8"
    body('/1/2/%D0%B8').must_equal 'm'
    body('/1/%D0%B8/2').must_equal 'n'

    status('/1/%D0%B82').must_equal 404
    status('/1/%D0%B9').must_equal 404
    status('/1/2/%D0%B9').must_equal 404
    status('/1/%D0%B9/2').must_equal 404
  end
end
