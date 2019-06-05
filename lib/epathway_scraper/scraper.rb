# frozen_string_literal: true

require "epathway_scraper/page/list_select"
require "epathway_scraper/page/search"
require "epathway_scraper/page/index"
require "epathway_scraper/page/date_search"

require "mechanize"

module EpathwayScraper
  # Scrape an epathway development applications site
  class Scraper
    attr_reader :base_url, :agent

    def initialize(base_url)
      @base_url = base_url + "/Web/GeneralEnquiry/EnquiryLists.aspx?ModuleCode=LAP"
      @agent = Mechanize.new
    end

    # list_type: one of :all, :advertising, :last_30_days, :all_year
    # state: NSW, VIC or NT, etc...
    def scrape(list_type:, state:, max_pages: nil, year: nil, force_detail: false)
      # Navigate to the correct list
      page = agent.get(base_url)
      page = Page::ListSelect.follow_javascript_redirect(page, agent)

      if list_type == :all
        Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
      elsif list_type == :advertising
        Page::ListSelect.select_advertising(page) if Page::ListSelect.on_page?(page)
      elsif list_type == :last_30_days
        page = Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
        Page::Search.pick(page, :last_30_days, agent)
      # Get all applications in a single year
      elsif list_type == :all_year
        page = Page::ListSelect.select_all(page) if Page::ListSelect.on_page?(page)
        page = Page::Search.click_date_search_tab(page, agent)
        Page::DateSearch.pick_all_year(page, year)
      else
        raise "Unexpected list_type: #{list_type}"
      end

      # Notice how we're skipping the clicking of search
      # even though that's what the user interface is showing next
      Page::Index.scrape_all_index_pages(
        max_pages, base_url, agent, force_detail, state
      ) do |record|
        yield record
      end
    end
  end
end
