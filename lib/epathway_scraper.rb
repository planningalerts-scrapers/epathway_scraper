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
    puts "Storing " + record["council_reference"] + " - " + record["address"]
    # puts record
    ScraperWiki.save_sqlite(["council_reference"], record)
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

    def scrape_and_save
      scrape { |record| save(record) }
    end

    def search_for_one_application(page, application_no)
      Page::Search.search_for_one_application(page, application_no)
    end

    def extract_table_data_and_urls(table)
      Table.extract_table_data_and_urls(table, base_url)
    end

    def extract_total_number_of_pages(page)
      Page::Index.extract_total_number_of_pages(page)
    end

    def scrape_detail_page(detail_page)
      Page::Detail.scrape(detail_page, base_url)
    end

    def extract_index_data(row)
      Page::Index.extract_index_data(row)
    end

    # list_type one of :advertising, :all, :last_30_days
    def pick_type_of_search(list_type)
      page = agent.get(base_url)

      # Checking whether we're on the right page
      page = Page::ListSelect.pick(page, list_type) if Page::ListSelect.on_page?(page)

      if list_type == :last_30_days
        # Fake that we're running javascript by picking out the javascript redirect
        redirected_url = page.body.match(/window.location.href='(.*)';/)[1]
        page = agent.get(redirected_url)

        page = Page::Search.click_date_search_tab(page, agent)
        # The Date tab defaults to a search range of the last 30 days.
        page = Page::Search.click_search(page) if Page::Search.on_page?(page)
      end
      page
    end

    def scrape_index_page(page)
      Page::Index.scrape_index_page(page, base_url, agent) do |record|
        yield record
      end
    end

    # TODO: max_pages is currently ignored if with_gets is false
    def scrape(list_type:, with_gets: false, max_pages: nil)
      # Navigate to the correct list
      page = pick_type_of_search(list_type)
      if with_gets
        # Notice how we're skipping the clicking of search
        # even though that's what the user interface is showing next
        Page::Index.scrape_all_index_pages_with_gets(max_pages, base_url, agent) do |record|
          yield record
        end
      else
        page = Page::Search.click_search(page) if Page::Search.on_page?(page)

        # And scrape everything
        Page::Index.scrape_all_index_pages(page, base_url, agent) do |record|
          yield record
        end
      end
    end
  end
end
