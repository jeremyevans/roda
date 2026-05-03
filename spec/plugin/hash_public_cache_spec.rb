require_relative '../spec_helper'

describe 'hash_public_cache plugin' do
  cache_file = "spec/tmp-hash-public-cache.json"

  before do
    app(:bare) do
      plugin :hash_public_cache, cache_file, root: 'spec/views'

      route do |r|
        hash_path(r.path_info[1..100])
      end
    end
  end

  after do
    File.delete(cache_file) if File.file?(cache_file)
  end

  it '.load_hash_public_cache_file loads the cache file' do
    File.write(cache_file, {"x" => "1"}.to_json)
    app.load_hash_public_cache_file
    body('/x').must_equal "/static/1/x"
  end

  it '.load_hash_public_cache_file handles case where file does not exist' do
    app.load_hash_public_cache_file
    body('/about.erb').must_equal "/static/zg5iunHNVtpPLbHhl02yuHOuZhIYC7KS8NgRiL7n9bU/about.erb"
  end

  it '.scan_hash_public_cache_dir scans public directory for files to calculate digests on' do
    app.scan_hash_public_cache_dir
    app.opts[:hash_public_cache]["about.erb"].must_equal "zg5iunHNVtpPLbHhl02yuHOuZhIYC7KS8NgRiL7n9bU"
    app.opts[:hash_public_cache].size.must_be :>, 1
  end

  it '.scan_hash_public_cache_dir does not rescan files that already have digests' do
    app.opts[:hash_public_cache]["about.erb"] = "1"
    app.scan_hash_public_cache_dir
    app.opts[:hash_public_cache]["about.erb"].must_equal "1"
    app.opts[:hash_public_cache].size.must_be :>, 1
  end

  it '.scan_hash_public_cache_dir respects block' do
    app.scan_hash_public_cache_dir{|f| f == "about.erb"}
    app.opts[:hash_public_cache]["about.erb"].must_equal "zg5iunHNVtpPLbHhl02yuHOuZhIYC7KS8NgRiL7n9bU"
    app.opts[:hash_public_cache].size.must_equal 1
  end

  it '.dump_hash_public_cache_file dumps cache to file' do
    app.opts[:hash_public_cache]["about.erb"] = "1"
    app.dump_hash_public_cache_file
    JSON.parse(File.read(cache_file)).must_equal({"about.erb" => "1"})
  end

  it '.load_hash_public_cache_file works as expected after .scan_hash_public_cache_dir and .dump_hash_public_cache_file' do
    app.scan_hash_public_cache_dir{|f| f == "about.erb"}
    app.opts[:hash_public_cache]["about.erb"].must_equal "zg5iunHNVtpPLbHhl02yuHOuZhIYC7KS8NgRiL7n9bU"
    app.opts[:hash_public_cache].size.must_equal 1
    app.dump_hash_public_cache_file
    app.opts[:hash_public_cache].clear
    app.load_hash_public_cache_file
    app.opts[:hash_public_cache]["about.erb"].must_equal "zg5iunHNVtpPLbHhl02yuHOuZhIYC7KS8NgRiL7n9bU"
    app.opts[:hash_public_cache].size.must_equal 1
  end
end
