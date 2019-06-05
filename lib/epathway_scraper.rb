# frozen_string_literal: true

require "epathway_scraper/version"
require "epathway_scraper/scraper"

require "scraperwiki"

# Top level module of gem
module EpathwayScraper
  def self.scrape_and_save(base_url, params)
    scrape(base_url, params) do |record|
      save(record)
    end
  end

  def self.scrape(params)
    params[:list_type] = params[:list]
    params.delete(:list)
    params2 = params.reject { |k, _v| k == :url }

    Scraper.new(params[:url]).scrape(params2) do |record|
      yield record
    end
  end

  def self.save(record)
    log(record)
    ScraperWiki.save_sqlite(["council_reference"], record)
  end

  def self.log(record)
    puts "Storing #{record['council_reference']} - #{record['address']}"
  end
end
