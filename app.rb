# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "json"
require "uri"

require "./lib/database.rb"

class SoyLatte < Sinatra::Base
  configure do
    set :config, YAML.load_file("./config.yaml")
  end
  
  before do
    query = params[:search_query]
    if query
      logfile = settings.config["logfile"]
      open(logfile,"a"){|f| f.puts("#{Time.now}\t#{query}") }
    end
  end
  
  get "/:source.css" do
    sass params[:source].intern
  end
  
  get "/" do
    m = Database.instance
    @instruments = m.instruments
    @species = JSON.dump(m.species)
    haml :index
  end
  
  post "/filter" do
    species = params[:species]
    study_type = params[:study_type]
    instrument = params[:platform]
    options = "species=#{species}&type=#{study_type}&instrument=#{instrument}"
    encoded = URI.encode(options)
    redirect to("/filter?#{encoded}")
  end
  
  get "/filter" do
    @species = params[:species]
    @type = params[:type]
    @instrument = params[:instrument]
    
    m = Database.instance
    @result = m.filter_result(@species, @type, @instrument)
  
    options = "species=#{@species}&type=#{@type}&instrument=#{@instrument}"
    @request_option = URI.encode(options)
  
    haml :filter
  end
  
  get "/donuts" do
    species = params[:species]
    type = params[:type]
    instrument = params[:instrument]
    content_type = "application/json"
    m = Database.instance
    JSON.dump(m.donuts_profile(species, type, instrument))
  end
  
  get "/data/filter" do
    m = Database.instance
    result = m.filter_result(params[:species], params[:type], params[:instrument])
    content_type = "application/json"
    JSON.dump(result)
  end
  
  post "/search" do
    m = Database.instance
    @query = params[:search_query]
    if @query =~ /^(S|E|D)R(A|P|X|R|S)\d{6}$/
      study_id = m.convert_to_study_id(@query)
      redirect to("/view/#{study_id}")
    else
      @result = m.search(@query,
                         species: params[:species],
                         type: params[:type],
                         instrument: params[:instrument])
      redirect "not_found", 404 if !@result
      haml :search
    end
  end
  
  get "/data/search" do
    m = Database.instance
    query = params[:query]
    result = m.search_api(query,
                          species: params[:species],
                          type: params[:type],
                          instrument: params[:instrument])
    if !result
      status 404
    else
      content_type "application/json"
      JSON.dump(result)
    end
  end
  
  get %r{/view/((S|E|D)RP\d{6})} do |id, db|
    m = Database.instance
    @report = m.project_report(id)
    haml :project
  end
  
  get %r{/data/((S|E|D)R(P|R)\d{6})} do |id, db, idtype|
    dtype = params[:dtype]
    retmode = params[:retmode]
    m = Database.instance
    result = m.data_retrieve(id, :retmode => retmode, :dtype => dtype)
    status 404 if !result
    case retmode
    when "tsv"
      content_type "text/tab-separated-values"
      result
    when "json"
      content_type "application/json"
      result
    end
  end
  
  get %r{/view/((S|E|D)RR\d{6}(|_1|_2))} do |id, db, read|
    m = Database.instance
    @report = m.run_report(id)
    status 404 if !@report
    haml :run
  end
  
  get %r{/fastqc/img/((S|E|D)RR\d{6}(|_1|_2))/(\w+)$} do |fname, db, read, img_fname|
    qc_path = settings.config["fqc_path"]
    pfx = fname.slice(0,6)
    id = fname.slice(0,9)
    img_path = File.join(qc_path, pfx, id, "#{fname}_fastqc/Images/#{img_fname}.png")
    send_file img_path
  end
  
  not_found do
    m = Database.instance
    @instruments = m.instruments
    @species = JSON.dump(m.species)
    haml :not_found
  end
end
