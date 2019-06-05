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
    def test_scraper(scraper_name, params)
      results = VCR.use_cassette(scraper_name) do
        Timecop.freeze(Date.new(2019, 5, 15)) do
          results = []

          params[:list_type] = params[:list]
          params.delete(:list)
          EpathwayScraper.scrape(
            params[:url],
            params.reject { |k, _v| k == :url }
          ) do |record|
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

    AUTHORITIES = {
      south_gippsland: {
        url: "https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd",
        state: "VIC",
        list: :advertising
      },
      campbelltown: {
        url: "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production",
        state: "NSW",
        list: :all
      },
      ballarat: {
        url: "https://eservices.ballarat.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :advertising
      },
      glen_eira: {
        url: "https://epathway-web.gleneira.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :all,
        max_pages: 4
      },
      gold_coast: {
        url: "https://cogc.cloud.infor.com/ePathway/epthprod",
        state: "QLD",
        list: :advertising
      },
      knox: {
        url: "https://eservices.knox.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :advertising
      },
      monash: {
        url: "https://epathway.monash.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :advertising
      },
      moreland: {
        url: "https://eservices.moreland.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :advertising
      },
      nillumbik: {
        url: "https://epathway.nillumbik.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :advertising
      },
      salisbury: {
        url: "https://eservices.salisbury.sa.gov.au/ePathway/Production",
        state: "SA",
        list: :last_30_days
      },
      adelaide: {
        url: "https://epathway.adelaidecitycouncil.com/epathway/ePathwayProd",
        state: "SA",
        list: :all_this_year
      },
      darebin: {
        url: "https://eservices.darebin.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :all_this_year
      },
      inverell: {
        url: "http://203.49.140.77/ePathway/Production",
        state: "NSW",
        list: :all_this_year
      },
      onkaparinga: {
        url: "http://pathway.onkaparinga.sa.gov.au/ePathway/Production",
        state: "SA",
        list: :all_this_year
      },
      unley: {
        url: "https://online.unley.sa.gov.au/ePathway/Production",
        state: "SA",
        list: :last_30_days
      },
      wollongong: {
        url: "http://epathway.wollongong.nsw.gov.au/ePathway/Production",
        state: "NSW",
        list: :advertising
      },
      yarra_ranges: {
        url: "https://epathway.yarraranges.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :all,
        max_pages: 20
      },
      barossa: {
        url: "https://epayments.barossa.sa.gov.au/ePathway/Production",
        state: "SA",
        list: :last_30_days,
        force_detail: true
      },
      kingston: {
        url: "https://online.kingston.vic.gov.au/ePathway/Production",
        state: "VIC",
        list: :all_this_year
      },
      greatlakes: {
        url: "https://services.greatlakes.nsw.gov.au/ePathway/Production",
        state: "NSW",
        list: :all,
        max_pages: 10
      },
      west_torrens: {
        url: "https://epathway.wtcc.sa.gov.au/ePathway/Production",
        state: "SA",
        list: :last_30_days
      },
      the_hills: {
        url: "https://epathway.thehills.nsw.gov.au/ePathway/Production",
        state: "NSW",
        list: :last_30_days
      }
    }.freeze

    AUTHORITIES.each do |scraper_name, params|
      it scraper_name do
        test_scraper(scraper_name, params)
      end
    end
  end
end
