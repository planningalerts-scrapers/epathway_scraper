require "timecop"

RSpec.describe EpathwayScraper do
  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  def test_scraper(scraper_name:, base_url:, list_type_name:)
    scraper = EpathwayScraper::Scraper.new(
      base_url: base_url,
      list_type_name: list_type_name
    )

    results = VCR.use_cassette(scraper_name) do
      Timecop.freeze(Date.new(2019,5,14)) do
        results = []
        scraper.scrape do |record|
          results << record
        end
        results.sort_by{|r| r["council_reference"]}
      end
    end

    expected = YAML.load(File.read("fixtures/expected/#{scraper_name}.yml"))

    expect(results).to eq expected
  end

  it "South_Gippsland_Shire_DAs" do
    test_scraper(
      scraper_name: "South_Gippsland_Shire_DAs",
      base_url: 'https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP',
      list_type_name: "Planning Application at Advertising"
    )
  end

  it "ballarat" do
    test_scraper(
      scraper_name: "ballarat",
      base_url: "https://eservices.ballarat.vic.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      list_type_name: "Planning Applications Currently on Advertising"
    )
  end

  it "campbelltown" do
    test_scraper(
      scraper_name: "campbelltown",
      base_url: "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      list_type_name: "Development Application Tracking"
    )
  end
end
