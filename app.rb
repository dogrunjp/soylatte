# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"

Configuration = YAML.load_file("./lib/config.yaml")
Logfile = Configuration["logfile"]

def logging(query)
  log = #{query} + "\t" + Time.now.to_s
  open(Logfile,"a"){|f| f.puts}
end

def query_filter(query_raw)
  "cleaned query"
end

def soy_search(query)
  [{ id: "SRP000001", paper: "11111111" }, { id: "ERP000001", paper: "22222222" }] if query
end

def get_material
  { id: "SRP000001",
    pmid: "11111111",
    text: "example project" }
end

set :haml, :format => :html5

before do
   logging(query) if params[:query]
end

get "/" do
  haml :index
end

post "/search" do
  @sp = params[:species]
  @st = params[:study_type]
  @pl = params[:platform]
  @qu = params[:search_query]

  query_raw = params[:query]
  query = query_filter(query_raw)
  @result = soy_search(query)
  if @result
    haml :search
  else
    haml :search_failed
  end
end

get %r{/view/((S|E|D)RP\d\{6\})$} do |id, db|
  @material = get_material(id)
  haml :view_project
end

not_found do
  haml :not_found
end
