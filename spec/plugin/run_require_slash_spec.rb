require_relative "../spec_helper"

describe "run_require_slash plugin" do 
  before do
    sub = app do |r|
      "sub-#{r.remaining_path}"
    end

    scope = self
    app(:bare) do
      scope.deprecated do
        plugin :match_affix, "", /(\/|\z)/
        plugin :run_require_slash
      end

      route do |r|
        r.on "/a" do |b|
          r.on "b" do |id, s|
            r.run sub
            "b-#{r.remaining_path}"
          end

          "albums-#{b}"
        end
      end
    end

  end

  deprecated "dispatches to application for empty PATH_INFO" do
    body("/a/b").must_equal 'sub-'
    body("/a/b/").must_equal 'sub-'
  end unless ENV['LINT']

  deprecated "dispatches to application for PATH_INFO starting with /" do
    body("/a/b//").must_equal 'sub-/'
  end

  deprecated "does not dispatch to application for PATH_INFO not starting with /" do
    body("/a/b/1").must_equal 'b-1'
  end
end
