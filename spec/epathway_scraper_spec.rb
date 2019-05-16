require "timecop"

RSpec.describe EpathwayScraper do
  before(:each) do
    File.delete("./data.sqlite") if File.exist?("./data.sqlite")
  end

  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  it "South_Gippsland_Shire_DAs" do
    scraper = EpathwayScraper::Scraper.new(
      base_url: 'https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP',
      index: 0
    )

    VCR.use_cassette("South_Gippsland_Shire_DAs") do
      Timecop.freeze(Date.new(2019,5,14)) do
        scraper.scrape_and_save
      end
    end

    expected = YAML.load(File.read("fixtures/expected/South_Gippsland_Shire_DAs.yml"))
    results = ScraperWiki.select("* from data order by council_reference")

    expect(results).to eq expected
  end
end
