require_relative "../spec_helper"

describe "relative_plath plugin" do 
  it "supports relative_path method to turn absolute paths into relative paths" do
    app(:relative_path) do |_|
      relative_path("/a")
    end

    body.must_equal './a'
    body('/a').must_equal './a'
    body('/a/').must_equal '../a'
    body('/a/b').must_equal '../a'
    body('/a/b/c').must_equal '../../a'
    body('/a/b/c', 'SCRIPT_NAME'=>'/d').must_equal '../../../a'
    unless_lint do
      body('', 'SCRIPT_NAME'=>'/d').must_equal './a'
      body('', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('a', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('/', 'SCRIPT_NAME'=>'d').must_equal '/a'
    end
  end

  it "supports relative_prefix method for prefix to turn absolute paths into relative paths" do
    app(:relative_path) do |_|
      "#{relative_prefix}/a"
    end

    body.must_equal './a'
    body('/a').must_equal './a'
    body('/a/').must_equal '../a'
    body('/a/b').must_equal '../a'
    body('/a/b/c').must_equal '../../a'
    body('/a/b/c', 'SCRIPT_NAME'=>'/d').must_equal '../../../a'
    unless_lint do
      body('', 'SCRIPT_NAME'=>'/d').must_equal './a'
      body('', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('a', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('/', 'SCRIPT_NAME'=>'d').must_equal '/a'
    end
  end

  it "supports multiple calls to relative_prefix while routing same request" do
    app(:relative_path) do |_|
      3.times.map{"#{relative_prefix}/a"}[0]
    end

    body.must_equal './a'
    body('/a').must_equal './a'
    body('/a/').must_equal '../a'
    body('/a/b').must_equal '../a'
    body('/a/b/c').must_equal '../../a'
    body('/a/b/c', 'SCRIPT_NAME'=>'/d').must_equal '../../../a'
    unless_lint do
      body('', 'SCRIPT_NAME'=>'/d').must_equal './a'
      body('', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('a', 'SCRIPT_NAME'=>'').must_equal '/a'
      body('/', 'SCRIPT_NAME'=>'d').must_equal '/a'
    end
  end
end
