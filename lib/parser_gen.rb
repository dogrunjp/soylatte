# -*- coding: utf-8 -*-

require "yaml"
require "open-uri"
require "json"
require "sra_metadata_parser"

class SRAParserGen
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    file_path = config["file_path"]
    @@accessions = file_path["sra_accessions"]
    @@run_members = file_path["sra_run_members"]
    @@pmc_ids = file_path["PMC-ids"]
    @@pmc_file_list = file_path["PMC_File_list"]
    @@xmlbase = file_path["xmlbase"]

    publication_url = file_path["publication"]
    publication_raw = open(publication_url).read
    publication_json = JSON.parse(publication_raw, :symbolize_names => true)
    @@publication = {}    
    publication_json[:ResultSet][:Result].each |node|
      @@publication[node[:sra_id].intern] ||= []
      @@publication[node[:sra_id].intern] << node[:pmid]
    end
  end
  
  def initialize(id)
    @id = id
    @id_type = id.slice(2,1)
    @subid = case @id_type
             when "A"
               id
             else
               `grep #{id} #{@@accessions} | cut -f 2 | sort -u`.chomp
             end
    @xml_head = File.join(@@xmlbase, @subid(0,6), @subid)
  end
  
  def submission_parser
    xml = File.join(xml_head, "#{@subid}.submission.xml")
    SRAMetadataParser::Submission.new(@subid, xml)
  end
  
  def study_parser
    studyid_arr = case @id_type
              when "P"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RP" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 5 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 13 | sort -u`.split("\n")
              end
    xml = File.join(xml_head, "#{@subid}.study.xml")
    studyid_arr.map do |studyid|
      SRAMetadataParser::Study.new(@studyid, xml)
    end
  end
  
  def experiment_parser
    expid_arr = case @id_type
              when "X"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RX" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 3 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 11 | sort -u`.split("\n")
              end
    xml = File.join(xml_head, "#{@subid}.experiment.xml")
    expid_arr.map do |expid|
      SRAMetadataParser::Experiment.new(@expid, xml)
    end
  end
  
  def sample_parser
    sampleid_arr = case @id_type
              when "S"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RS" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 4 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 12 | sort -u`.split("\n")
              end
    xml = File.join(xml_head, "#{@subid}.sample.xml")
    sampleid_arr.map do |sampleid|
      SRAMetadataParser::Sample.new(@sampleid, xml)
    end
  end
  
  def run_parser
    runid_arr = case @id_type
              when "R"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RR" | cut -f 1 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@run_members} | cut -f 1 | sort -u`.split("\n")
              end
    xml = File.join(xml_head, "#{@subid}.run.xml")
    runid_arr.map do |runid|
      SRAMetadataParser::Run.new(@runid, xml)
    end
  end
  
  def pubmed_parser
    pmid = @@publication[@subid.intern]
    
  end
  
  def pmc_parser
    pmcid = @@publication[@subid.intern].map do |pmid|
      `grep #{pmid} #{@@pmc_ids}`.split(",")[8]
    end
  end
end

