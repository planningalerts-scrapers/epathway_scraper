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

    def scrape(list_type:, max_pages: nil)
      # Navigate to the correct list
      page = agent.get(base_url)
      page = Page::ListSelect.follow_javascript_redirect(page, agent)

      if list_type == :all
        Page::ListSelect.pick(page, :all) if Page::ListSelect.on_page?(page)
      elsif list_type == :advertising
        Page::ListSelect.pick(page, :advertising) if Page::ListSelect.on_page?(page)
      elsif list_type == :last_30_days
        page = Page::ListSelect.pick(page, :all) if Page::ListSelect.on_page?(page)
        Page::Search.pick(page, :last_30_days, agent)
      else
        raise "Unexpected list_type: #{list_type}"
      end

      # Notice how we're skipping the clicking of search
      # even though that's what the user interface is showing next
      Page::Index.scrape_all_index_pages(max_pages, base_url, agent) do |record|
        yield record
      end
    end
  end
end
