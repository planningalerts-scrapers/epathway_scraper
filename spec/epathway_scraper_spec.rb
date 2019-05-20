# frozen_string_literal: true

require "timecop"

RSpec.describe EpathwayScraper do
  it "has a version number" do
    expect(EpathwayScraper::VERSION).not_to be nil
  end

  def test_scraper(scraper_name:, base_url:, list_type:)
    scraper = EpathwayScraper::Scraper.new(
      base_url: base_url,
      list_type: list_type
    )

    results = VCR.use_cassette(scraper_name) do
      Timecop.freeze(Date.new(2019, 5, 14)) do
        results = []
        scraper.scrape do |record|
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
      # rubocop:disable Metrics/LineLength
      base_url: "https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      # rubocop:enable Metrics/LineLength
      list_type: :advertising
    )
  end

  it "ballarat" do
    test_scraper(
      scraper_name: "ballarat",
      # rubocop:disable Metrics/LineLength
      base_url: "https://eservices.ballarat.vic.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      # rubocop:enable Metrics/LineLength
      list_type: :advertising
    )
  end

  it "campbelltown" do
    test_scraper(
      scraper_name: "campbelltown",
      # rubocop:disable Metrics/LineLength
      base_url: "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP",
      # rubocop:enable Metrics/LineLength
      list_type: :all
    )
  end
end
