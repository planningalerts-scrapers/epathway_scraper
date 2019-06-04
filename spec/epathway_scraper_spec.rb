# frozen_string_literal: true

require "timecop"

RSpec.describe EpathwayScraper do
  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  describe ".save" do
    let(:record) { { "foo" => 1, "council_reference" => "ABC", "address" => "here" } }

    it "should save a record to the local sqlite database" do
      EpathwayScraper.save(record)
      expect(ScraperWiki.select("* from data")).to eq [record]
    end
  end

  describe "Scraper" do
    def test_scraper(scraper_name:, params:)
      results = VCR.use_cassette(scraper_name) do
        Timecop.freeze(Date.new(2019, 5, 15)) do
          results = []
          EpathwayScraper.scrape(*params) do |record|
            results << record
          end
          results.sort_by { |r| r["council_reference"] }
        end
      end

      expected = if File.exist?("fixtures/expected/#{scraper_name}.yml")
                   YAML.safe_load(File.read("fixtures/expected/#{scraper_name}.yml"))
                 else
                   []
                 end

      if results != expected
        # Overwrite expected so that we can compare with version control
        # (and maybe commit if it is correct)
        File.open("fixtures/expected/#{scraper_name}.yml", "w") do |f|
          f.write(results.to_yaml)
        end
      end

      expect(results).to eq expected
    end

    SCRAPERS = [
      {
        scraper_name: "south_gippsland",
        params: [
          "https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "campbelltown",
        params: [
          "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production",
          { list_type: :all }
        ]
      },
      {
        scraper_name: "ballarat",
        params: [
          "https://eservices.ballarat.vic.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "glen_eira",
        params: [
          "https://epathway-web.gleneira.vic.gov.au/ePathway/Production",
          { list_type: :all, max_pages: 4 }
        ]
      },
      {
        scraper_name: "gold_coast",
        params: [
          "https://cogc.cloud.infor.com/ePathway/epthprod",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "knox",
        params: [
          "https://eservices.knox.vic.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "monash",
        params: [
          "https://epathway.monash.vic.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "moreland",
        params: [
          "https://eservices.moreland.vic.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "nillumbik",
        params: [
          "https://epathway.nillumbik.vic.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "salisbury",
        params: [
          "https://eservices.salisbury.sa.gov.au/ePathway/Production",
          { list_type: :last_30_days }
        ]
      },
      {
        scraper_name: "adelaide",
        params: [
          "https://epathway.adelaidecitycouncil.com/epathway/ePathwayProd",
          { list_type: :all_year, year: 2019 }
        ]
      },
      {
        scraper_name: "darebin",
        params: [
          "https://eservices.darebin.vic.gov.au/ePathway/Production",
          { list_type: :all_year, year: 2019 }
        ]
      },
      {
        scraper_name: "inverell",
        params: [
          "http://203.49.140.77/ePathway/Production",
          { list_type: :all_year, year: 2019 }
        ]
      },
      {
        scraper_name: "onkaparinga",
        params: [
          "http://pathway.onkaparinga.sa.gov.au/ePathway/Production",
          { list_type: :all_year, year: 2019 }
        ]
      },
      {
        scraper_name: "unley",
        params: [
          "https://online.unley.sa.gov.au/ePathway/Production",
          { list_type: :last_30_days }
        ]
      },
      {
        scraper_name: "wollongong",
        params: [
          "http://epathway.wollongong.nsw.gov.au/ePathway/Production",
          { list_type: :advertising }
        ]
      },
      {
        scraper_name: "yarra_ranges",
        params: [
          "https://epathway.yarraranges.vic.gov.au/ePathway/Production",
          { list_type: :all, max_pages: 20 }
        ]
      },
      {
        scraper_name: "barossa",
        params: [
          "https://epayments.barossa.sa.gov.au/ePathway/Production",
          { list_type: :last_30_days, force_detail: true }
        ]
      },
      {
        scraper_name: "kingston",
        params: [
          "https://online.kingston.vic.gov.au/ePathway/Production",
          { list_type: :all_year, year: 2019 }
        ]
      },
      {
        scraper_name: "greatlakes",
        params: [
          "https://services.greatlakes.nsw.gov.au/ePathway/Production",
          { list_type: :all, max_pages: 10 }
        ]
      },
      {
        scraper_name: "west_torrens",
        params: [
          "https://epathway.wtcc.sa.gov.au/ePathway/Production",
          { list_type: :last_30_days }
        ]
      },
      {
        scraper_name: "the_hills",
        params: [
          "https://epathway.thehills.nsw.gov.au/ePathway/Production",
          { list_type: :last_30_days }
        ]
      }
    ].freeze

    SCRAPERS.each do |scraper|
      it scraper[:scraper_name] do
        test_scraper(scraper)
      end
    end
  end
end
