require_relative "../spec_helper"

describe "match_affix plugin" do 
  deprecated "allows changing the match prefix/suffix" do
    app(:bare) do
      plugin :match_affix, "", /(\/|\z)/

      route do |r|
        r.on "/albums" do |b|
          r.on "b/:id" do |id, s|
            "b-#{b}-#{id}-#{s.inspect}"
          end

          "albums-#{b}"
        end
      end
    end

    body("/albums/a/1").must_equal 'albums-/'
    body("/albums/b/1").must_equal 'b-/-1-""'
  end

  deprecated "handles extra trailing slash only" do
    app(:bare) do
      plugin :match_affix, nil, /(?:\/\z|(?=\/|\z))/

      route do |r|
        r.on "albums" do
          r.on "b" do
            "albums/b:#{r.remaining_path}"
          end

          "albums:#{r.remaining_path}"
        end
      end
    end

    body("/albums/a").must_equal 'albums:/a'
    body("/albums/a/").must_equal 'albums:/a/'
    body("/albums/b").must_equal 'albums/b:'
    body("/albums/b/").must_equal 'albums/b:'
  end

  deprecated "allows changing the match prefix without suffix" do
    app(:bare) do
      plugin :match_affix, ""

      route do |r|
        r.on "/albums" do
          r.on "/b" do
            "albums-b-#{r.remaining_path}"
          end

          "albums-#{r.remaining_path}"
        end
      end
    end

    body("/albums/a/1").must_equal 'albums-/a/1'
    body("/albums/b/1").must_equal 'albums-b-/1'
  end
end
