#!/usr/bin/env ruby
require 'erb'
require 'yaml'
require '../lib/roda/version'
def data(filename,*keys)
  path = "#{Dir.pwd}/data/#{filename}.yml"
  db = YAML.load ERB.new(File.read path).result
  # db = YAML.load_file(path)
  eval "db#{ keys.map { |key| "[\"#{ key }\"]"}.join() }"
end
def embed(url)
  id = url.split('v=').last.split("&").first
  src = "https://www.youtube.com/embed/#{id}?showinfo=0"
  "<iframe src='#{src}' frameborder='0' allow='autoplay;encrypted-media' allowfullscreen></iframe>"
end
def titleize(string)
  string.slice(0,1).capitalize + string.slice(1..-1)
end
Dir.chdir(File.dirname(__FILE__))
erb = ERB.new(File.read('layout.erb'), nil, '-')
Dir['pages/*.erb'].each do |page|
  public_loc = "#{page.gsub(/\Apages\//, 'public/').sub('.erb', '.html')}"
  content = ERB.new(File.read(page), nil, '-').result(binding)
  current_page = File.basename(page.sub('.erb', ''))
  title = data(:site, :pages, current_page, :title)
  description = data(:site, :pages, current_page, :description)
  File.open(public_loc, 'wb'){|f| f.write(erb.result(binding))}
end


