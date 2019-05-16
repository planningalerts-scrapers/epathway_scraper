require "timecop"

RSpec.describe EpathwayScraper do
  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  it "South_Gippsland_Shire_DAs" do
    scraper = EpathwayScraper::Scraper.new(
      base_url: 'https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP',
      index: 0
    )

    results = VCR.use_cassette("South_Gippsland_Shire_DAs") do
      Timecop.freeze(Date.new(2019,5,14)) do
        results = []
        scraper.scrape do |record|
          results << record
        end
        results.sort_by{|r| r["council_reference"]}
      end
    end

    expected = YAML.load(File.read("fixtures/expected/South_Gippsland_Shire_DAs.yml"))

    expect(results).to eq expected
  end

  it "ballarat" do
    scraper = EpathwayScraper::Scraper.new(
      base_url: "https://eservices.ballarat.vic.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      index: 0
    )

    results = VCR.use_cassette("ballarat") do
      Timecop.freeze(Date.new(2019,5,14)) do
        results = []
        scraper.scrape do |record|
          results << record
        end
        results.sort_by{|r| r["council_reference"]}
      end
    end

    expected = YAML.load(File.read("fixtures/expected/ballarat.yml"))

    expect(results).to eq expected
  end
end
