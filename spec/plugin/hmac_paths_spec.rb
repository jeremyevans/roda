require_relative "../spec_helper"

describe "hmac_paths plugin" do 
  def hmac_paths_app(&block)
    app(:bare) do
      plugin :hmac_paths, secret: '1'*32
      route(&block)
    end
  end

  it "plugin requires :secret option be string at least 32 bytes for HMAC secret" do
    proc{app.plugin :hmac_paths}.must_raise Roda::RodaError
    proc{app.plugin :hmac_paths, secret: 1}.must_raise Roda::RodaError
    proc{app.plugin :hmac_paths, secret: '1'}.must_raise Roda::RodaError
    proc{app.plugin :hmac_paths, secret: '1'*31}.must_raise Roda::RodaError
  end

  it "plugin requires :old_secret option be string at least 32 bytes for HMAC secret if given" do
    proc{app.plugin :hmac_paths, secret: '1'*32, old_secret: 1}.must_raise Roda::RodaError
    proc{app.plugin :hmac_paths, secret: '1'*32, old_secret: '1'}.must_raise Roda::RodaError
    proc{app.plugin :hmac_paths, secret: '1'*32, old_secret: '1'*31}.must_raise Roda::RodaError
  end

  it "hmac_path method requires path argument be a string" do
    hmac_paths_app{|r| hmac_path(1)}
    proc{body}.must_raise Roda::RodaError
  end

  it "hmac_path method requires path argument must start with /" do
    hmac_paths_app{|r| hmac_path('1')}
    proc{body}.must_raise Roda::RodaError
  end

  it "hmac_path method returns path with HMAC" do
    hmac_paths_app{|r| hmac_path('/1')}
    body.must_equal "/1dd95fe7d0dbe409f852e81a7c2cc4c93971c04542a150c6baefe00876e28f13/0/1"
  end

  it "hmac_path HMAC depends on path argument" do
    hmac_paths_app do |r|
      r.get('a'){hmac_path('/2')}
      hmac_path('/1')
    end
    body.must_equal "/1dd95fe7d0dbe409f852e81a7c2cc4c93971c04542a150c6baefe00876e28f13/0/1"
    body('/a').must_equal "/adf4707dcc97605cdaeea144bba055ed330ae2d1d23025150d7cbf181af6cd63/0/2"
  end

  it "hmac_path method requires :root option be a string" do
    hmac_paths_app{|r| hmac_path('/1', root: 1)}
    proc{body}.must_raise Roda::RodaError
  end

  it "hmac_path method requires :root option must start with /" do
    hmac_paths_app{|r| hmac_path('/1', root: '1')}
    proc{body}.must_raise Roda::RodaError
  end

  it "hmac_path uses :root option for path prefix" do
    hmac_paths_app do |r|
      hmac_path('/1', root: '/foo')
    end
    body.must_equal "/foo/ee408306c4e9a5ba5e57d295fe5cbb2b82e252b636d67c2a15039cc265611210/0/1"
  end

  it "hmac_path HMAC depends on :root option" do
    hmac_paths_app do |r|
      r.get('a'){hmac_path('/1', root: '/bar')}
      hmac_path('/1', root: '/foo')
    end
    body.must_equal "/foo/ee408306c4e9a5ba5e57d295fe5cbb2b82e252b636d67c2a15039cc265611210/0/1"
    body('/a').must_equal "/bar/5ba0452a430fca1802eb93b52f2d994b58d768374ba318253cbc50c326e46f95/0/1"
  end

  it "hmac_path sets m flag for :method option" do
    hmac_paths_app do |r|
      hmac_path('/1', method: :get)
    end
    body.must_equal "/e21ef288ee8316f0d8e67eae55a2f27edda28316c3c231f4425281f6d291bccc/m/1"
  end

  it "hmac_path HMAC depends on :method option" do
    hmac_paths_app do |r|
      r.get('a'){hmac_path('/1', method: :post)}
      hmac_path('/1', method: :get)
    end
    body.must_equal "/e21ef288ee8316f0d8e67eae55a2f27edda28316c3c231f4425281f6d291bccc/m/1"
    body('/a').must_equal "/72644ba25f4253acbe5f26370ca948d31f8fa0041fc77ddc9dc92da22415d1cd/m/1"
  end

  it "hmac_path sets p flag and adds query string parameters for :params option" do
    hmac_paths_app do |r|
      hmac_path('/1', params: {foo: :bar})
    end
    body.must_equal "/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c/p/1?foo=bar"
  end

  it "hmac_path HMAC depends on :params option" do
    hmac_paths_app do |r|
      r.get('a'){hmac_path('/1', params: {bar: :foo})}
      hmac_path('/1', params: {foo: :bar})
    end
    body.must_equal "/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c/p/1?foo=bar"
    body('/a').must_equal "/1785c857e23dfd04c127162d292f557cd2db4b0a6ac9c39515c85ce9ff404165/p/1?bar=foo"
  end

  it "hmac_path sets t flag for :seconds and :until options" do
    t = Time.utc(2100).to_i
    seconds = t - Time.now.to_i
    hmac_paths_app do |r|
      r.get('s'){hmac_path('/1', seconds: seconds)}
      hmac_path('/1', until: 3)
    end
    body.must_equal "/78a56ddf0e081ca127ab1bc704c8a4d5e7e62ccf327dec5c3189a5c72057334c/t/3/1"
    body('/s').must_match %r"/64e31560c6df065b6116599c370aca918cfcbde092724b94f2770192ae513a28/t/4102444800/1|/f0206d644636000f733df59dcff98c763ca56d209ee4737c72e1b0fe35013913/t/4102444801/1"
  end

  it "hmac_path HMAC depends on :seconds and :until options" do
    t = Time.utc(2100).to_i
    seconds = t - Time.now.to_i
    hmac_paths_app do |r|
      r.on(Integer) do |v|
        r.get('s'){hmac_path('/1', seconds: seconds - v)}
        hmac_path('/1', until: v)
      end
    end
    body('/3').must_equal "/78a56ddf0e081ca127ab1bc704c8a4d5e7e62ccf327dec5c3189a5c72057334c/t/3/1"
    body('/3/s').must_match %r"(/9ffb7ce6b6ae76664aeebc53955c7c1d8d09e6908a512a6b5f22e7a24fffdc15/t/4102444797/1|/534c367b6c6154fb84e8a6ce6118a560b261306a7c35cb210e1cee98dd5d431a/t/4102444798/1)"
    body('/4').must_equal "/f04e6d0571e2f3322bfa03b4b251070b7cdbde1004726fd69ded8cb40d1fb4ae/t/4/1"
    body('/4/s').must_match %r"(/ecc641d021a3cccd6f3931e41f75f3bbdc9b05791b0ac939278b306e40571c86/t/4102444796/1|/9ffb7ce6b6ae76664aeebc53955c7c1d8d09e6908a512a6b5f22e7a24fffdc15/t/4102444797/1)"
  end

  it "hmac_path gives priority to :until option over seconds option" do
    hmac_paths_app do |r|
      hmac_path('/1', until: 3, seconds: 2)
    end
    body.must_equal "/78a56ddf0e081ca127ab1bc704c8a4d5e7e62ccf327dec5c3189a5c72057334c/t/3/1"
  end

  it "hmac_path HMAC depends on :namespace option" do
    hmac_paths_app do |r|
      r.is String, String do |ns, path|
        hmac_path("/#{path}", namespace: ns)
      end
    end
    body('/1/1').must_equal "/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1"
    body('/1/2').must_equal "/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2"
    body('/2/1').must_equal "/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1"
    body('/2/2').must_equal "/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2"
  end

  it "hmac_path HMAC depends on :namespace and :root option" do
    hmac_paths_app do |r|
      r.is String, String, String do |root, ns, path|
        hmac_path("/#{path}", namespace: ns, root: "/#{root}")
      end
    end
    body('/1/1/1').must_equal "/1/6a8eb2d9a041cbec93bf1228d16065c30990979c8708d95fc7f598ce33582bf5/n/1"
    body('/1/1/2').must_equal "/1/9fda9fa5aeddaa182e578f9ff021c8144719278f73c9bf262437d1cd914f60a9/n/2"
    body('/1/2/1').must_equal "/1/bd0f071316f51dc663cbed519f480642fbda34b8fddd4e5741dc85ff47f67e3c/n/1"
    body('/1/2/2').must_equal "/1/2d8ee8168bbc3bd421f9e2e87a61394d849598c0c7616e0648027decd2168e3a/n/2"
    body('/2/1/1').must_equal "/2/9f3cf91195e00ccdd49dad755c63faeab69df4b4aa28c1204b46732009f63660/n/1"
    body('/2/1/2').must_equal "/2/bc8774a718a5e5b900956f4cd7c68e69fb21191efcc200bb6e239c330b1ef0cf/n/2"
    body('/2/2/1').must_equal "/2/aff7e70387307b017b8b560325c3f6cfe9fbe3f92434a32279410427086b50ca/n/1"
    body('/2/2/2').must_equal "/2/39a307cf0cb83d29cf7fa18831978eb7de8ace532e052c6fa760564fbb2324a9/n/2"
  end

  it "hmac_path HMAC depends on default namespace via :namespace_session_key" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.is String do |path|
          hmac_path("/#{path}")
        end
      end
    end
    session['nsk'] = 1
    body('/1').must_equal "/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1"
    body('/2').must_equal "/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2"
    session['nsk'] = 2
    body('/1').must_equal "/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1"
    body('/2').must_equal "/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2"
  end

  it "hmac_path allows overriding default namespace via explicit namespace option" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.is String, String do |ns, path|
          hmac_path("/#{path}", namespace: ns)
        end
        hmac_path(r.remaining_path, namespace: nil)
      end
    end
    session['nsk'] = 1
    body('/1/1').must_equal "/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1"
    body('/1/2').must_equal "/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2"
    body('/2/1').must_equal "/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1"
    body('/2/2').must_equal "/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2"

    body('/1').must_equal "/1dd95fe7d0dbe409f852e81a7c2cc4c93971c04542a150c6baefe00876e28f13/0/1"
    body('/2').must_equal "/adf4707dcc97605cdaeea144bba055ed330ae2d1d23025150d7cbf181af6cd63/0/2"
  end

  it "r.hmac_path does not yield if remaining path does not start with /" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status('503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c').must_equal 404
  end unless ENV['LINT']

  it "r.hmac_path does not yield if hmac segment is not 64 bytes" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status('/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443/0/').must_equal 404
  end

  it "r.hmac_path does not yield if there is no flags or empty flags segment" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status('/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c').must_equal 404
    status('/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c/').must_equal 404
    status('/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c//').must_equal 404
  end

  it "r.hmac_path does not yield if there is no remaining path after flags segment" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status('/503907ffeb039fa93b0e6d0728d30c2fef4b10d655aef6e1ac23347b2159443c/m').must_equal 404
  end

  it "r.hmac_path does not yield if a namespace is provided and not required or not provided and required" do
    hmac_paths_app{|r| r.hmac_path(namespace: r.GET['ns']){r.remaining_path}}
    status('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1').must_equal 404
    status('/1dd95fe7d0dbe409f852e81a7c2cc4c93971c04542a150c6baefe00876e28f13/0/1', 'QUERY_STRING'=>'ns=1').must_equal 404
  end

  it "r.hmac_path does not yield if there is a namespace provided and required but it doesn't match" do
    hmac_paths_app{|r| r.hmac_path(namespace: r.GET['ns']){r.remaining_path}}
    status('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd776/n/1', 'QUERY_STRING'=>'ns=1').must_equal 404
    status('/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ab/n/2', 'QUERY_STRING'=>'ns=1').must_equal 404
    status('/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d6/n/1', 'QUERY_STRING'=>'ns=2').must_equal 404
    status('/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c5/n/2', 'QUERY_STRING'=>'ns=2').must_equal 404
  end

  it "r.hmac_path does not yield if there is a namespace provided and required but it doesn't match, when not at the root" do
    hmac_paths_app do |r|
      r.on String do 
        r.hmac_path(namespace: r.GET['ns']){r.remaining_path}
      end
    end
    status("/1/6a8eb2d9a041cbec93bf1228d16065c30990979c8708d95fc7f598ce33582bf4/n/1", 'QUERY_STRING'=>'ns=1').must_equal 404
    status("/1/9fda9fa5aeddaa182e578f9ff021c8144719278f73c9bf262437d1cd914f60a8/n/2", 'QUERY_STRING'=>'ns=1').must_equal 404
    status("/1/bd0f071316f51dc663cbed519f480642fbda34b8fddd4e5741dc85ff47f67e3b/n/1", 'QUERY_STRING'=>'ns=2').must_equal 404
    status("/1/2d8ee8168bbc3bd421f9e2e87a61394d849598c0c7616e0648027decd2168e39/n/2", 'QUERY_STRING'=>'ns=2').must_equal 404
    status("/2/9f3cf91195e00ccdd49dad755c63faeab69df4b4aa28c1204b46732009f6366f/n/1", 'QUERY_STRING'=>'ns=1').must_equal 404
    status("/2/bc8774a718a5e5b900956f4cd7c68e69fb21191efcc200bb6e239c330b1ef0ce/n/2", 'QUERY_STRING'=>'ns=1').must_equal 404
    status("/2/aff7e70387307b017b8b560325c3f6cfe9fbe3f92434a32279410427086b50c9/n/1", 'QUERY_STRING'=>'ns=2').must_equal 404
    status("/2/39a307cf0cb83d29cf7fa18831978eb7de8ace532e052c6fa760564fbb2324a8/n/2", 'QUERY_STRING'=>'ns=2').must_equal 404
  end

  it "r.hmac_path does not yield if there is a default namespace provided via :namespace_session_key and required but it doesn't match" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.hmac_path{r.remaining_path}
      end
    end
    session['nsk'] = 1
    status('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd776/n/1').must_equal 404
    status('/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ab/n/2').must_equal 404
    session['nsk'] = 2
    status('/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d6/n/1').must_equal 404
    status('/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c5/n/2').must_equal 404
  end

  it "r.hmac_path only yields if hmac path matches" do
    hmac_paths_app do |r|
      r.get 'path', String do |path|
        hmac_path("/#{path}", root: '')
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    path = body('/path/1')
    body(path).must_equal '/1'
    status(path.chop + '2').must_equal 404
    status(path.sub(%r|./0/1\z|, '/0/1')).must_equal 404
    status(path.sub(%r|0/1\z|, '1/1')).must_equal 404
  end

  it "r.hmac_path does not support using path designed for one root with a different root" do
    hmac_paths_app do |r|
      r.get 'root', String do |root|
        hmac_path("/1", root: "/#{root}")
      end

      r.on Integer do
        r.hmac_path do
          r.remaining_path
        end
      end
    end
    root1_path = body('/root/1')
    root2_path = body('/root/2')
    status(root1_path.sub(/\A\/1/, '/2')).must_equal 404
    status(root2_path.sub(/\A\/2/, '/1')).must_equal 404
  end

  it "r.hmac_path for non-method-specific path works for any request method" do
    hmac_paths_app do |r|
      r.get 'path' do
        hmac_path("/1")
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    path = body('/path')
    body(path).must_equal '/1'
    body(path, 'REQUEST_METHOD'=>'POST').must_equal '/1'
  end

  it "r.hmac_path for method-specific path only works for specified request method" do
    hmac_paths_app do |r|
      r.get 'method', String do |meth|
        hmac_path("/1", method: meth)
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    get_path = body('/method/get')
    post_path = body('/method/post')
    body(get_path).must_equal '/1'
    body(post_path, 'REQUEST_METHOD'=>'POST').must_equal '/1'
    status(get_path, 'REQUEST_METHOD'=>'POST').must_equal 404
    status(post_path).must_equal 404
  end

  it "r.hmac_path for non-param-specific path only works with any query string" do
    hmac_paths_app do |r|
      r.get 'path' do
        hmac_path("/1")
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    path = body('/path')
    body(path).must_equal '/1'
    body(path, 'QUERY_STRING'=>'a=b').must_equal '/1'
  end

  it "r.hmac_path for param-specific path only works for specified query string" do
    hmac_paths_app do |r|
      r.get 'params', String, String, String, String do |k1, v1, k2, v2|
        hmac_path("/1", params: {k1=>v1, k2=>v2})
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    params1_path = body('/params/a/b/c/d')
    params2_path = body('/params/c/d/a/b')
    p1, qs1 = params1_path.split('?', 2)
    p2, qs2 = params2_path.split('?', 2)
    status(p1).must_equal 404
    status(p2).must_equal 404
    body(p1, 'QUERY_STRING'=>qs1).must_equal '/1'
    body(p2, 'QUERY_STRING'=>qs2).must_equal '/1'
    status(p1, 'QUERY_STRING'=>qs2).must_equal 404
    status(p2, 'QUERY_STRING'=>qs1).must_equal 404
  end

  it "r.hmac_path yields if the path is timestamped, hmac matches, and before the timestamp" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    body('/ecc641d021a3cccd6f3931e41f75f3bbdc9b05791b0ac939278b306e40571c86/t/4102444796/1').must_equal '/1'
  end

  it "r.hmac_path does not yield if the path is timestamped, hmac matches, and not before the timestamp" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status("/78a56ddf0e081ca127ab1bc704c8a4d5e7e62ccf327dec5c3189a5c72057334c/t/3/1").must_equal 404
  end

  it "r.hmac_path does not yield if the path is timestamped and hmac does not match" do
    hmac_paths_app{|r| r.hmac_path{r.remaining_path}}
    status('/ecc641d021a3cccd6f3931e41f75f3bbdc9b05791b0ac939278b306e40571c85/t/4102444796/1').must_equal 404
  end

  it "r.hmac_path yields if there is a namespace provided and required and it matches" do
    hmac_paths_app{|r| r.hmac_path(namespace: r.GET['ns']){r.remaining_path}}
    body('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1', 'QUERY_STRING'=>'ns=1').must_equal '/1'
    body('/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2', 'QUERY_STRING'=>'ns=1').must_equal '/2'
    body('/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1', 'QUERY_STRING'=>'ns=2').must_equal '/1'
    body('/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2', 'QUERY_STRING'=>'ns=2').must_equal '/2'
  end

  it "r.hmac_path yields if there is a namespace provided and required and it matches, when not at the root" do
    hmac_paths_app do |r|
      r.on String do 
        r.hmac_path(namespace: r.GET['ns']){r.remaining_path}
      end
    end
    body("/1/6a8eb2d9a041cbec93bf1228d16065c30990979c8708d95fc7f598ce33582bf5/n/1", 'QUERY_STRING'=>'ns=1').must_equal '/1'
    body("/1/9fda9fa5aeddaa182e578f9ff021c8144719278f73c9bf262437d1cd914f60a9/n/2", 'QUERY_STRING'=>'ns=1').must_equal '/2'
    body("/1/bd0f071316f51dc663cbed519f480642fbda34b8fddd4e5741dc85ff47f67e3c/n/1", 'QUERY_STRING'=>'ns=2').must_equal '/1'
    body("/1/2d8ee8168bbc3bd421f9e2e87a61394d849598c0c7616e0648027decd2168e3a/n/2", 'QUERY_STRING'=>'ns=2').must_equal '/2'
    body("/2/9f3cf91195e00ccdd49dad755c63faeab69df4b4aa28c1204b46732009f63660/n/1", 'QUERY_STRING'=>'ns=1').must_equal '/1'
    body("/2/bc8774a718a5e5b900956f4cd7c68e69fb21191efcc200bb6e239c330b1ef0cf/n/2", 'QUERY_STRING'=>'ns=1').must_equal '/2'
    body("/2/aff7e70387307b017b8b560325c3f6cfe9fbe3f92434a32279410427086b50ca/n/1", 'QUERY_STRING'=>'ns=2').must_equal '/1'
    body("/2/39a307cf0cb83d29cf7fa18831978eb7de8ace532e052c6fa760564fbb2324a9/n/2", 'QUERY_STRING'=>'ns=2').must_equal '/2'
  end

  it "r.hmac_path yields if there is a namespace provided via :namespace_session_key and it matches" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.hmac_path{r.remaining_path}
      end
    end
    session['nsk'] = 1
    body('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1').must_equal '/1'
    body('/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2').must_equal '/2'
    session['nsk'] = 2
    body('/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1').must_equal '/1'
    body('/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2').must_equal '/2'
  end

  it "r.hmac_path yields if there is a namespace provided via :namespace_session_key and it matches, when not at the root" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.on String do
          r.hmac_path{r.remaining_path}
        end
      end
    end
    session['nsk'] = 1
    body("/1/6a8eb2d9a041cbec93bf1228d16065c30990979c8708d95fc7f598ce33582bf5/n/1").must_equal '/1'
    body("/1/9fda9fa5aeddaa182e578f9ff021c8144719278f73c9bf262437d1cd914f60a9/n/2").must_equal '/2'
    body("/2/9f3cf91195e00ccdd49dad755c63faeab69df4b4aa28c1204b46732009f63660/n/1").must_equal '/1'
    body("/2/bc8774a718a5e5b900956f4cd7c68e69fb21191efcc200bb6e239c330b1ef0cf/n/2").must_equal '/2'
    session['nsk'] = 2
    body("/1/bd0f071316f51dc663cbed519f480642fbda34b8fddd4e5741dc85ff47f67e3c/n/1").must_equal '/1'
    body("/1/2d8ee8168bbc3bd421f9e2e87a61394d849598c0c7616e0648027decd2168e3a/n/2").must_equal '/2'
    body("/2/aff7e70387307b017b8b560325c3f6cfe9fbe3f92434a32279410427086b50ca/n/1").must_equal '/1'
    body("/2/39a307cf0cb83d29cf7fa18831978eb7de8ace532e052c6fa760564fbb2324a9/n/2").must_equal '/2'
  end

  it "r.hmac_path with :namespace option overrides namespace provided via :namespace_session_key" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.hmac_path(namespace: r.GET['ns']){r.remaining_path}
      end
    end
    session['nsk'] = 2
    body('/4ac78addcebf8b8e00c901e127934c6e4dd4ac0b76dcc9d837099bea01afd777/n/1', 'QUERY_STRING'=>'ns=1').must_equal '/1'
    body('/7e34d4cbe1d20878f3cc1db93d18eda19690b9ba985344057e847c2447d285ac/n/2', 'QUERY_STRING'=>'ns=1').must_equal '/2'
    session['nsk'] = 1
    body('/4107c5423d997ea30266f666907e703bbe7e83e1e0b1fc3d5d8bdf0e85aa84d7/n/1', 'QUERY_STRING'=>'ns=2').must_equal '/1'
    body('/602cd4704d8c7ec0af4bcd640f0dfb3a16460b1c6115ad09e3aed71c4ebdd6c6/n/2', 'QUERY_STRING'=>'ns=2').must_equal '/2'
  end

  it "r.hmac_path works as expected with :root, :method, and :params options" do
    hmac_paths_app do |r|
      r.get 'path', String, String, String, String do |r, m, k1, v1|
        hmac_path("/1", root: "/#{r}", method: m, params: {k1=>v1})
      end

      r.on Integer do
        r.hmac_path do
          r.remaining_path
        end
      end
    end
    path1 = body('/path/1/get/c/d')
    path2 = body('/path/2/post/a/b')
    p1, qs1 = path1.split('?', 2)
    p2, qs2 = path2.split('?', 2)
    body(p1, 'QUERY_STRING'=>qs1).must_equal '/1'
    body(p2, 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal '/1'

    # No query string
    status(p1).must_equal 404
    status(p2).must_equal 404
    # Query string mismatch
    status(p1, 'QUERY_STRING'=>qs2).must_equal 404
    status(p2, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
    # Request method mismatch
    status(p1, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
    status(p2, 'QUERY_STRING'=>qs2).must_equal 404
    # Root mismatch
    status(p1.sub(/\A\/1/, '/2'), 'QUERY_STRING'=>qs1).must_equal 404
    status(p2.sub(/\A\/2/, '/1'), 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal 404
  end

  it "r.hmac_path works as expected with :root, :method, :params, and :namespace options" do
    hmac_paths_app do |r|
      r.get 'path', String, String, String, String do |root, m, k1, v1|
        hmac_path("/1", root: "/#{root}", method: m, params: {k1=>v1}, namespace: r.GET['ns'])
      end

      r.on Integer do
        ns = r.GET['ns']
        env['QUERY_STRING'] = env['QUERY_STRING'].sub('&ns=1', '') if env['QUERY_STRING']
        r.hmac_path(namespace: ns) do
          r.remaining_path
        end
      end
    end
    path1 = body('/path/1/get/c/d', 'QUERY_STRING'=>'ns=1')
    path2 = body('/path/2/post/a/b', 'QUERY_STRING'=>'ns=1')
    p1, qs1 = path1.split('?', 2)
    p2, qs2 = path2.split('?', 2)
    qs1 += '&ns=1'
    qs2 += '&ns=1'
    body(p1, 'QUERY_STRING'=>qs1).must_equal '/1'
    body(p2, 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal '/1'

    # No query string
    status(p1).must_equal 404
    status(p2).must_equal 404
    # Query string mismatch
    status(p1, 'QUERY_STRING'=>qs2).must_equal 404
    status(p2, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
    # Request method mismatch
    status(p1, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
    status(p2, 'QUERY_STRING'=>qs2).must_equal 404
    # Root mismatch
    status(p1.sub(/\A\/1/, '/2'), 'QUERY_STRING'=>qs1).must_equal 404
    status(p2.sub(/\A\/2/, '/1'), 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal 404
    # Namespace mismatch
    qs1[-1] = '2'
    qs2[-1] = '2'
    status(p1.sub(/\A\/1/, '/2'), 'QUERY_STRING'=>qs1).must_equal 404
    status(p2.sub(/\A\/2/, '/1'), 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal 404
  end

  it "r.hmac_path works as expected with :root, :method, and :params options and default namespace via :namespace_session_key" do
    session = {}
    app(:bare) do
      define_method(:session){session}
      plugin :hmac_paths, secret: '1'*32, namespace_session_key: 'nsk'
      
      route do |r|
        r.get 'path', String, String, String, String do |root, m, k1, v1|
          hmac_path("/1", root: "/#{root}", method: m, params: {k1=>v1})
        end

        r.on Integer do
          r.hmac_path do
            r.remaining_path
          end
        end
      end
    end
    [nil, 1, 2].each do |nsk|
      session['nsk'] = nsk
      path1 = body('/path/1/get/c/d')
      path2 = body('/path/2/post/a/b')
      p1, qs1 = path1.split('?', 2)
      p2, qs2 = path2.split('?', 2)
      body(p1, 'QUERY_STRING'=>qs1).must_equal '/1'
      body(p2, 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal '/1'

      # No query string
      status(p1).must_equal 404
      status(p2).must_equal 404
      # Query string mismatch
      status(p1, 'QUERY_STRING'=>qs2).must_equal 404
      status(p2, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
      # Request method mismatch
      status(p1, 'QUERY_STRING'=>qs1, 'REQUEST_METHOD'=>'POST').must_equal 404
      status(p2, 'QUERY_STRING'=>qs2).must_equal 404
      # Root mismatch
      status(p1.sub(/\A\/1/, '/2'), 'QUERY_STRING'=>qs1).must_equal 404
      status(p2.sub(/\A\/2/, '/1'), 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal 404
      # Namespace mismatch
      session['nsk'] = 3
      status(p1.sub(/\A\/1/, '/2'), 'QUERY_STRING'=>qs1).must_equal 404
      status(p2.sub(/\A\/2/, '/1'), 'QUERY_STRING'=>qs2, 'REQUEST_METHOD'=>'POST').must_equal 404
    end
  end

  it "r.hmac_path handles secret rotation using :old_secret option" do
    hmac_paths_app do |r|
      r.get 'path', String do |path|
        hmac_path("/#{path}", root: '')
      end

      r.hmac_path do
        r.remaining_path
      end
    end
    path = body('/path/1')
    body(path).must_equal '/1'
    app.plugin :hmac_paths, secret: '2'*32
    status(path).must_equal 404
    app.plugin :hmac_paths, secret: '2'*32, old_secret: '1'*32
    body(path).must_equal '/1'
    app.plugin :hmac_paths, secret: '2'*32, old_secret: '3'*32
    status(path).must_equal 404
  end

  it "example code in documation is accurate" do
    app(:bare) do
      plugin :hmac_paths, secret: 'some-secret-value-with-at-least-32-bytes'

      route do |r|
        r.on 'root', String do |root|
          hmac_path(r.remaining_path, root: "/#{root}")
        end

        r.on 'method', String do |method|
          hmac_path(r.remaining_path, method: method)
        end

        r.on 'params', String, String do |k, v|
          hmac_path(r.remaining_path, params: {k=>v})
        end

        r.on 'until' do
          hmac_path(r.remaining_path, until: Time.utc(2100))
        end

        r.on 'seconds' do
          hmac_path(r.remaining_path, seconds: Time.utc(2100).to_i - Time.now.to_i)
        end

        r.on 'namespace', String do |ns|
          hmac_path(r.remaining_path, namespace: ns)
        end

        r.on 'all', String, String, String, String, String do |root, method, k, v, ns|
          hmac_path(r.remaining_path, root: "/#{root}", method: method, params: {k=>v}, namespace: ns)
        end

        hmac_path(r.remaining_path)
      end
    end

    body('/widget/1').must_equal "/0c2feaefdfc80cc73da19b060c713d4193c57022815238c6657ce2d99b5925eb/0/widget/1"
    body('/root/widget/1').must_equal "/widget/daccafce3ce0df52e5ce774626779eaa7286085fcbde1e4681c74175ff0bbacd/0/1"
    body('/root/foobar/1').must_equal "/foobar/c5fdaf482771d4f9f38cc13a1b2832929026a4ceb05e98ed6a0cd5a00bf180b7/0/1"
    body('/method/get/widget/1').must_equal "/d38c1e634ecf9a3c0ab9d0832555b035d91b35069efcbf2670b0dfefd4b62fdd/m/widget/1"
    body('/params/foo/bar/widget/1').must_equal "/fe8d03f9572d5af6c2866295bd3c12c2ea11d290b1cbd016c3b68ee36a678139/p/widget/1?foo=bar"
    body('/until/widget/1').must_equal "/dc8b6e56e4cbe7815df7880d42f0e02956b2e4c49881b6060ceb0e49745a540d/t/4102444800/widget/1"
    ["/dc8b6e56e4cbe7815df7880d42f0e02956b2e4c49881b6060ceb0e49745a540d/t/4102444800/widget/1",
     "/b5df5f9a6bef3635528c36ed15c0b83cdaedeac43abb8227e2a59cad9630808a/t/4102444801/widget/1"].must_include body('/seconds/widget/1')
    body('/namespace/1/widget/1').must_equal "/3793ac2a72ea399c40cbd63f154d19f0fe34cdf8d347772134c506a0b756d590/n/widget/1"
    body('/namespace/2/widget/1').must_equal "/0e1e748860d4fd17fe9b7c8259b1e26996502c38e465f802c2c9a0a13000087c/n/widget/1"
    body('/all/widget/get/foo/bar/1/1').must_equal "/widget/c14c78a81d34d766cf334a3ddbb7a6b231bc2092ef50a77ded0028586027b14e/mpn/1?foo=bar"
  end
end
