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
    def test_scraper(scraper_name:, base_url:, scrape_params:)
      scraper = EpathwayScraper::Scraper.new(base_url)

      results = VCR.use_cassette(scraper_name) do
        Timecop.freeze(Date.new(2019, 5, 15)) do
          results = []
          scraper.scrape(scrape_params) do |record|
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

    it "South_Gippsland_Shire_DAs" do
      test_scraper(
        scraper_name: "South_Gippsland_Shire_DAs",
        base_url: "https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd",
        scrape_params: {
          list_type: :advertising
        }
      )
    end

    it "ballarat" do
      test_scraper(
        scraper_name: "ballarat",
        base_url: "https://eservices.ballarat.vic.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :advertising
        }
      )
    end

    it "campbelltown" do
      test_scraper(
        scraper_name: "campbelltown",
        base_url: "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :all
        }
      )
    end

    it "glen_eira" do
      test_scraper(
        scraper_name: "glen_eira",
        base_url: "https://epathway-web.gleneira.vic.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :all, with_gets: true, max_pages: 4
        }
      )
    end

    it "gold_coast" do
      test_scraper(
        scraper_name: "gold_coast",
        base_url: "https://cogc.cloud.infor.com/ePathway/epthprod",
        scrape_params: {
          list_type: :advertising, with_gets: true
        }
      )
    end

    it "knox" do
      test_scraper(
        scraper_name: "knox",
        base_url: "https://eservices.knox.vic.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :advertising
        }
      )
    end

    it "monash" do
      test_scraper(
        scraper_name: "monash",
        base_url: "https://epathway.monash.vic.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :advertising, with_gets: true
        }
      )
    end

    it "moreland" do
      test_scraper(
        scraper_name: "moreland",
        base_url: "https://eservices.moreland.vic.gov.au/ePathway/Production",
        scrape_params: {
          list_type: :advertising, with_gets: true
        }
      )
    end
  end
end
