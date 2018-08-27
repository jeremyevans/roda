use Rack::Static, :urls=>%w'/index.html /why.html /documentation.html /development.html /compare-to-sinatra.html /css /rdoc /images /js', :root=>'public'
run proc{[302, {'Content-Type'=>'text/html', 'Location'=>'index.html'}, []]}
