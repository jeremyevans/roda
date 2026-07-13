require_relative "../spec_helper"

describe "url_escape plugin" do 
  it "support URL escaping and unescaping" do
    app(:url_escape) do |r|
      r.get :name do |name|
        unescaped = url_unescape(name)
        escaped = url_escape(name)
        "#{url_escape(unescaped)}-#{url_unescape(escaped)}-#{escaped}-#{unescaped}"
      end
    end

    body('/%61+').must_equal 'a+-%61+-%2561%2B-a '
  end
end
