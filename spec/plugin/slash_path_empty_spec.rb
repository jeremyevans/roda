require_relative "../spec_helper"

describe "slash_path_empty" do 
  it "considers a / path as empty" do
    app(:slash_path_empty) do |r|
      r.is{"1"}
      r.is("a"){"2"}
      r.get("b"){"3"}
    end

    unless_lint do
      body("").must_equal '1'
      body("a").must_equal ''
      body("b").must_equal ''
    end
    body.must_equal '1'
    body("/a").must_equal '2'
    body("/a/").must_equal '2'
    body("/a/b").must_equal ''
    body("/b").must_equal '3'
    body("/b/").must_equal '3'
    body("/b/c").must_equal ''
  end
end
