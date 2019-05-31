# frozen_string_literal: true

require "epathway_scraper/version"
require "epathway_scraper/page/list_select"
require "epathway_scraper/page/search"
require "epathway_scraper/page/index"
require "epathway_scraper/page/detail"
require "epathway_scraper/table"

require "scraperwiki"
require "mechanize"
require "English"

# Top level module of gem
module EpathwayScraper
  def self.save(record)
    log(record)
    ScraperWiki.save_sqlite(["council_reference"], record)
  end

  def self.log(record)
    puts "Storing " + record["council_reference"] + " - " + record["address"]
  end

  # Scrape an epathway development applications site
  class Scraper
    attr_reader :base_url, :agent

    def initialize(base_url)
      @base_url = base_url + "/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP"
      @agent = Mechanize.new
    end

    # Convenience method
    def self.scrape_and_save(base_url, params)
      scrape(base_url, params) do |record|
        EpathwayScraper.save(record)
      end
    end

    # Convenience method
    def self.scrape(base_url, params)
      new(base_url).scrape(params) do |record|
        yield record
      end
    end

    def search_for_one_application(page, application_no)
      Page::Search.search_for_one_application(page, application_no)
    end

    # list_type one of :advertising, :all, :last_30_days
    def pick_type_of_search(list_type)
      page = agent.get(base_url)
      page = Page::ListSelect.follow_javascript_redirect(page, agent)

      # Checking whether we're on the right page
      if Page::ListSelect.on_page?(page)
        if %i[all last_30_days].include?(list_type)
          page = Page::ListSelect.pick(page, :all)
        elsif list_type == :advertising
          page = Page::ListSelect.pick(page, :advertising)
        else
          raise "Unexpected list_type: #{list_type}"
        end
      end

      page = Page::Search.pick(page, :last_30_days, agent) if list_type == :last_30_days

      page
    end

    def scrape_index_page(page)
      Page::Index.scrape_index_page(page, base_url, agent) do |record|
        yield record
      end
    end

    def scrape(list_type:, max_pages: nil)
      # Navigate to the correct list
      pick_type_of_search(list_type)
      # Notice how we're skipping the clicking of search
      # even though that's what the user interface is showing next
      Page::Index.scrape_all_index_pages(max_pages, base_url, agent) do |record|
        yield record
      end
    end
  end
end
