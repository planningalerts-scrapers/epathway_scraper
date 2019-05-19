require "epathway_scraper/version"

require 'scraperwiki'
require 'mechanize'

module EpathwayScraper
  class Scraper
    attr_reader :base_url, :agent, :index

    def initialize(base_url:, index:)
      @base_url = base_url
      @index = index
      @agent = Mechanize.new
    end

    def scrape_and_save
      scrape do |record|
        puts "Storing " + record['council_reference'] + " - " + record['address']
      #      puts record
        ScraperWiki.save_sqlite(['council_reference'], record)
      end
    end

    def click_search_on_page(page)
      button = page.form.button_with(:value => "Search")
      if button
        page.form.submit(button)
      else
        page
      end
    end

    # Also include the urls of links
    def extract_table_data_and_urls(table)
      headings = table.at("tr.ContentPanelHeading").search("th").map{|th| th.inner_text}
      table.search("tr.ContentPanel, tr.AlternateContentPanel").map do |tr|
        content = tr.search("td").map{|td| td.inner_text}
        url = (URI.parse(base_url) + tr.at("a")["href"]).to_s if tr.at("a")
        r = {}
        content.each_with_index do |value, index|
          r[headings[index]] = value
        end
        { content: r, url: url }
      end
    end

    def scrape_detail_page(detail_page)
      # Find the table that contains the addresses
      table = detail_page.search("table.ContentPanel").find do |table|
        extract_table_data_and_urls(table)[0][:content].keys.include?("Property Address")
      end
      # Find the address of the primary location
      row = extract_table_data_and_urls(table).find { |row| row[:content]["Primary Location"] == "Yes" }
      address = row[:content]["Property Address"]

      {
        council_reference: field(detail_page, "Application Number"),
        description: field(detail_page, "Proposed Use or Development"),
        # TODO: Do this more sensibly based on knowledge of the date format
        date_received: Date.parse(field(detail_page, "Date Received")).to_s,
        address: address
      }
    end

    def extract_index_data(row)
      result = {
        council_reference: row[:content]["App No."] || row[:content]["Application Number"] || row[:content]["Application number"],
        address: row[:content]["Location Address"] || row[:content]["Property Address"] || (row[:content]["Address"] + ", " + row[:content]["Suburb"] + ", VIC"),
        description: row[:content]["Proposed Use or Development"] || row[:content]["Description"] || row[:content]["Application Proposal"],
        # This URL will only work in a session. Thanks for that!
        detail_url: row[:url]
      }
      if row[:content]["Date Lodged"]
        result[:date_received] = Date.strptime(row[:content]["Date Lodged"], '%d/%m/%Y').to_s
      elsif row[:content]["Application Date"]
        result[:date_received] = Date.strptime(row[:content]["Application Date"], '%d/%m/%Y').to_s
      end
      result
    end

    def pick_type_of_search
      page = agent.get(base_url)
      form = page.forms.first
      form.radiobuttons[index].click
      form.submit(form.button_with(:value => /Next/))
    end

    def scrape_index_page(page)
      extract_table_data_and_urls(page.at("table.ContentPanel")).each do |row|
        data = extract_index_data(row)

        # Check if we have all the information we need from the index_data
        # If so then there's no need to scrape the detail page
        unless data.has_key?(:council_reference) &&
               data.has_key?(:address) &&
               data.has_key?(:description) &&
               data.has_key?(:date_received)

          detail_page = agent.get(data[:detail_url])
          data = scrape_detail_page(detail_page)
        end

        yield({
          'council_reference' => data[:council_reference],
          'address' => data[:address],
          'description' => data[:description],
          'info_url' => base_url,
          'date_scraped' => Date.today.to_s,
          'date_received' => data[:date_received],
        })
      end
    end

    def click_next_page_link(page, page_no)
      next_link = page.links_with(:text => (page_no + 1).to_s)[0]
      return if !next_link
      params = /javascript:WebForm_DoPostBackWithOptions\(new WebForm_PostBackOptions\("([^"]*)", "", false, "", "([^"]*)", false, true\)\)/.match(next_link.href)

      aspnetForm = page.forms_with(:name => "aspnetForm")[0]
      aspnetForm.action = params[2]
      aspnetForm['__EVENTTARGET'] = params[1]
      aspnetForm['__EVENTARGUMENT'] = ""

      agent.submit(aspnetForm)
    end

    def scrape_all_index_pages(page)
      page_no = 1
      loop do
        scrape_index_page(page) do |record|
          yield record
        end

        page = click_next_page_link(page, page_no)
        break if page.nil?
        page_no += 1
      end
    end

    def scrape
      # Navigate to the correct list
      page = pick_type_of_search
      page = click_search_on_page(page)

      # And scrape everything
      scrape_all_index_pages(page) do |record|
        yield record
      end
    end

    private

    def field(page, name)
      page.at("span:contains(\"#{name}\")").next.inner_text.to_s.strip
    end
  end
end
