# frozen_string_literal: true

require "epathway_scraper/version"

require "scraperwiki"
require "mechanize"

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
      @base_url = base_url
      @agent = Mechanize.new
    end

    def scrape_and_save
      scrape { |record| save(record) }
    end

    def click_search_on_page(page)
      button = page.form.button_with(value: "Search")
      if button
        page.form.submit(button)
      else
        page
      end
    end

    # Also include the urls of links
    def extract_table_data_and_urls(table)
      headings = table.at("tr.ContentPanelHeading").search("th").map(&:inner_text)
      table.search("tr.ContentPanel, tr.AlternateContentPanel").map do |tr|
        content = tr.search("td").map(&:inner_text)
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
      table = detail_page.search("table.ContentPanel").find do |t|
        extract_table_data_and_urls(t)[0][:content].keys.include?("Property Address")
      end
      # Find the address of the primary location
      row = extract_table_data_and_urls(table).find { |r| r[:content]["Primary Location"] == "Yes" }
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
        council_reference: row[:content]["App No."] ||
                           row[:content]["Application Number"] ||
                           row[:content]["Application number"],
        address: row[:content]["Location Address"] ||
                 row[:content]["Property Address"] ||
                 row[:content]["Site Location"] ||
                 (row[:content]["Address"] + ", " + row[:content]["Suburb"] + ", VIC"),
        description: row[:content]["Proposed Use or Development"] ||
                     row[:content]["Description"] ||
                     row[:content]["Application Proposal"] ||
                     row[:content]["Proposal"],
        # This URL will only work in a session. Thanks for that!
        detail_url: row[:url]
      }
      if row[:content]["Date Lodged"]
        result[:date_received] = Date.strptime(row[:content]["Date Lodged"], "%d/%m/%Y").to_s
      elsif row[:content]["Application Date"]
        result[:date_received] = Date.strptime(row[:content]["Application Date"], "%d/%m/%Y").to_s
      end
      result
    end

    def pick_type_of_search(list_type)
      page = agent.get(base_url)
      form = page.forms.first

      button_texts = page.search('input[type="radio"]').map { |i| i.parent.next.inner_text }
      index_advertising = button_texts.index("Planning Application at Advertising") ||
                          button_texts.index("Planning Applications Currently on Advertising") ||
                          button_texts.index("Development Applications On Public Exhibition") ||
                          button_texts.index("Planning Permit Applications Advertised")
      raise "Couldn't find index for :advertising in #{button_texts}" if index_advertising.nil?

      index_all = button_texts.index("Development Application Tracking") ||
                  button_texts.index("Town Planning Public Register") ||
                  button_texts.index("Planning Application Register") ||
                  button_texts.index("Planning Permit Application Search")
      raise "Couldn't find index for :all in #{button_texts}" if index_all.nil?

      if list_type == :advertising
        index = index_advertising
      elsif list_type == :all
        index = index_all
      else
        raise "Unexpected list type: #{list_type}"
      end

      form.radiobuttons[index].click
      form.submit(form.button_with(value: /Next/))
    end

    def scrape_index_page(page)
      extract_table_data_and_urls(page.at("table.ContentPanel")).each do |row|
        data = extract_index_data(row)

        # Check if we have all the information we need from the index_data
        # If so then there's no need to scrape the detail page
        unless data.key?(:council_reference) &&
               data.key?(:address) &&
               data.key?(:description) &&
               data.key?(:date_received)

          detail_page = agent.get(data[:detail_url])
          data = scrape_detail_page(detail_page)
        end

        yield({
          "council_reference" => data[:council_reference],
          "address" => data[:address],
          "description" => data[:description],
          "info_url" => base_url,
          "date_scraped" => Date.today.to_s,
          "date_received" => data[:date_received]
        })
      end
    end

    def click_next_page_link(page, page_no)
      next_link = page.links_with(text: (page_no + 1).to_s)[0]
      return unless next_link

      # rubocop:disable Metrics/LineLength
      # TODO: Fix this long unreadable line
      params = /javascript:WebForm_DoPostBackWithOptions\(new WebForm_PostBackOptions\("([^"]*)", "", false, "", "([^"]*)", false, true\)\)/.match(next_link.href)
      # rubocop:enable Metrics/LineLength

      aspnet_form = page.forms_with(name: "aspnetForm")[0]
      aspnet_form.action = params[2]
      aspnet_form["__EVENTTARGET"] = params[1]
      aspnet_form["__EVENTARGUMENT"] = ""

      agent.submit(aspnet_form)
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

    def scrape(list_type)
      # Navigate to the correct list
      page = pick_type_of_search(list_type)
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
