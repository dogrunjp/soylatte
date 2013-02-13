# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "json"
require "uri"

require "./lib/database"
require "./lib/project_report"
require "./lib/run_report"

require "ap"

def logging(query)
  logfile = settings.config["logfile"]
  log = Time.now.to_s + "\t" + query
  open(logfile,"a"){|f| f.puts(log) }
end

def query_filter(query)
  size = query.size
  invalid_char = settings.config["invalid_char"]
  if size > 140 || size < 2
    valid_query = query.force_encoding("utf-8")
    invalid_char.each do |char|
      valid_query.gsub!(char, "")
    end
    valid_query
  end
end

def type_ref(type)
  ref = { "Genome" => 1,
          "Transcriptome" => 2,
          "Epigenome" => 3,
          "Metagenome" => 4,
          "Cancer Genomics" => 5,
          "Other" => 0 }
  ref[type]
end

set :haml, :format => :html5

configure do
  set :config, YAML.load_file("./config.yaml")
end

before do
  query = params[:search_query]
  logging(query) if query
end

get "/style.css" do
  sass :style
end

get "/soy_style.css" do
  sass :soy_style
end

get "/" do
  @instruments = Database.instance.instruments
  @organisms = JSON.dump(Database.instance.scientific_names)
  haml :index
end

post "/filter" do
  scientific_name = params[:species]
  study_type = params[:study_type]
  instrument = params[:platform]
  options = "species=#{scientific_name}&type=#{study_type}&instrument=#{instrument}"
  encoded = URI.encode(options)
  redirect to("/filter?#{encoded}")
end  

get "/filter" do
  @scientific_name = params[:species]
  @type = params[:type]
  @instrument = params[:instrument]
  
  taxonid = Database.instance.name2taxonid(@scientific_name) if !@scientific_name.empty?
  study_type = type_ref(@type)
  
  @condition = { taxonid: taxonid,
                 study_type: study_type,
                 instrument: @instrument }
  @total_number = Database.instance.size
  @result = Database.instance.filter(@condition)
  haml :filter
end

post "/search" do
  @condition = { scientific_name: params[:species],
                 study_type: type_ref(params[:type]),
                 instrument: params[:instrument] }

  @query = query_filter(params[:search_query])
  if @query
    @result = Database.instance.search_fulltext(@query, @condition)
    if @result.empty?
      haml :not_found
    else
      haml :search
    end
  else
    haml :not_found
  end
end

get %r{/view/((S|E|D)RP\d{6})} do |id, db|
  @report = ProjectReport.new(id, "./config.yaml").report
  haml :view_project
end

get %r{/data/((S|E|D)R(P|R)\d{6})} do |id, db, idtype|
  dtype = params[:type]
  retmode = params[:retmode]
  case idtype
  when "P"
    report = ProjectReport.new(id, "./config.yaml").report
    case dtype
    when "run"
      run_table = report[:run_table]
      case retmode
      when "tsv"
        run_table.map{|n| n.values.join("\t") }.join("\n")
      when "json"
        JSON.dump(run_table.map{|n| n.values })
      else
        haml :not_found
      end
    when "sample"
      sample_table = report[:sample_table]
      case retmode
      when "tsv"
        sample_table.map{|n| n.values.join("\t") }.join("\n")
      when "json"
        JSON.dump(sample_table.map{|n| n.values })
      else
        haml :not_found
      end
    else
      haml :not_found
    end
  #when "R"
  else
    haml :not_found
  end
end

get %r{/view/((S|E|D)RR\d{6}(|_1|_2))} do |id, db, read|
  RunReport.load_files("./config.yaml")
  run_report = RunReport.new(id)
  if run_report
    @report = run_report.report
    haml :view_run
  else
    haml :not_found
  end
end

get %r{/fastqc/img/((S|E|D)RR\d{6}(|_1|_2))/(\w+)$} do |fname, db, read, img_fname|
  qc_path = settings.config["fqc_path"]
  pfx = fname.slice(0,6)
  id = fname.slice(0,9)
  img_path = File.join(qc_path, pfx, id, "#{fname}_fastqc/Images/#{img_fname}.png")
  send_file img_path
end

not_found do
  @instruments = Database.instance.instruments
  @organisms = JSON.dump(Database.instance.scientific_names)
  haml :not_found
end
