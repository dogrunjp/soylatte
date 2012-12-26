# -*- coding: utf-8 -*-

require "yaml"
require "groonga"
require "parallel"
require "./metadata_parser"

def create_facet_db(db_path)
  Groonga::Database.create(:path => db_path)

  Groonga::Schema.create_table("Projects", :type => :hash)
  Groonga::Schema.change_table("Projects") do |table|
    table.uint16("runid")
    table.uint16("taxonid")
    table.uint16("study_type")
    table.short_text("instrument")
    table.text("fulltext")
    table.bool("paper")
  end
  
  Groonga::Schema.create_table("Idx_int", :type => :hash)
  Groonga::Schema.change_table("Idx_int") do |table|
    table.index("Projects.runid")
    table.index("Projects.taxonid")
    table.index("Projects.study_type")
    table.index("Projects.instrument")
    table.index("Projects.paper")
  end
  
  Groonga::Schema.create_table("Idx_text",
    type: :patricia_trie,
    key_normalize: true,
    default_tokenizer: "TokenBigram"
  )
  Groonga::Schema.change_table("Idx_text") do |table|
    table.index("Projects.fulltext")
  end
end

def add_record(insert)
  db = Groonga["Projects"]
  studyid = insert[:studyid]
  db.add(studyid)
  
  record = db[studyid]
  record.runid = insert[:runid]
  record.taxonid = insert[:taxonid]
  record.study_type = insert[:study_type]
  record.instrument = insert[:instrument]
  record.fulltext = insert[:fulltext]
  record.paper = insert[:paper]  
end

if __FILE__ == $0
  config_path = "./config.yaml"
  config = YAML.load_file(config_path)
  db_path = config["db_path"]

  Groonga::Context.default_options = { encoding: :utf8 }
  case ARGV.first
  when "--up"
    create_facet_db(db_path)
  
  when "--update"
    accessions = config["file_path"]["sra_accessions"]
    studyids = `grep '^ERP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1 | sort -u`.split("\n")
    
    FacetParser.load_files(config_path)
    
    inserts = Parallel.map(studyids) do |studyid|
      f = FacetParser.new(studyid)
      f.insert
    end
    
    Groonga::Database.open(db_path)
    Parallel.each(inserts) do |insert|
      add_record(insert)
    end
  end
end