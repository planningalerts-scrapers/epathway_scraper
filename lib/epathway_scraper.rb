# frozen_string_literal: true

require "epathway_scraper/version"

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

    def click_search_on_page(page)
      button = page.form.button_with(value: "Search")
      if button
        page.form.submit(button)
      else
        page
      end
    end

    def click_date_search_tab(page)
      table = page.at("table.tabcontrol")
      href = table.search("a").find { |a| a.inner_text == "Date Search" }["href"]
      # Extract target and argument of postback from href
      match = href.match(/javascript:__doPostBack\('(.*)','(.*)'\)/)
      raise "Link isn't a postback link" if match.nil?

      form = page.forms.first
      raise "Can't find form for postback" if form.nil?

      form["__EVENTTARGET"] = match[1]
      form["__EVENTARGUMENT"] = match[2]
      agent.submit(form)
    end

    def search_for_one_application(page, application_no)
      form = page.form
      field = form.field_with(name: /FormattedNumberTextBox/)
      field.value = application_no
      button = form.button_with(value: "Search")
      form.submit(button)
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

    def extract_total_number_of_pages(page)
      page_label = page.at("#ctl00_MainBodyContent_mPagingControl_pageNumberLabel")
      if page_label.nil?
        # If we can't find the label assume there is only one page of results
        1
      elsif page_label.inner_text =~ /Page \d+ of (\d+)/
        $LAST_MATCH_INFO[1].to_i
      else
        raise "Unexpected form for number of pages"
      end
    end

    def scrape_detail_page(detail_page)
      address = field(detail_page, "Application location")
      # If address is stored in a table at the bottom
      if address.nil?
        # Find the table that contains the addresses
        table = detail_page.search("table.ContentPanel").find do |t|
          extract_table_data_and_urls(t)[0][:content].keys.include?("Property Address")
        end
        # Find the address of the primary location
        row = extract_table_data_and_urls(table).find do |r|
          r[:content]["Primary Location"] == "Yes"
        end
        address = row[:content]["Property Address"]
      end

      {
        council_reference: field(detail_page, "Application Number") ||
          field(detail_page, "Application number"),
        description: field(detail_page, "Proposed Use or Development") ||
          field(detail_page, "Application description"),
        date_received: Date.strptime(
          field(detail_page, "Date Received") || field(detail_page, "Lodgement date"),
          "%d/%m/%Y"
        ).to_s,
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
                 row[:content]["Application location"] ||
                 row[:content]["Application Location"] ||
                 row[:content]["Location"] ||
                 row[:content]["Primary Property Address"] ||
                 row[:content]["Site Address"] ||
                 (if row[:content]["Address"] && row[:content]["Suburb"]
                    (row[:content]["Address"] + ", " + row[:content]["Suburb"] + ", VIC")
                  end) ||
                 row[:content]["Address"],
        description: row[:content]["Proposed Use or Development"] ||
                     row[:content]["Description"] ||
                     row[:content]["Application Proposal"] ||
                     row[:content]["Proposal"] ||
                     row[:content]["Application Description"] ||
                     row[:content]["Application proposal"],
        # This URL will only work in a session. Thanks for that!
        detail_url: row[:url]
      }
      date_received = row[:content]["Date Lodged"] ||
                      row[:content]["Date lodged"] ||
                      row[:content]["Application Date"] ||
                      row[:content]["Lodgement Date"] ||
                      row[:content]["Date received"] ||
                      row[:content]["Date"]
      result[:date_received] = Date.strptime(date_received, "%d/%m/%Y").to_s if date_received
      result
    end

    # type can be either :advertising or :all
    def pick_type_of_application(page, type)
      form = page.forms.first

      button_texts = page.search('input[type="radio"]').map { |i| i.parent.next.inner_text }

      index = if type == :advertising
                button_texts.index("Planning Application at Advertising") ||
                  button_texts.index("Planning Applications Currently on Advertising") ||
                  button_texts.index("Development Applications On Public Exhibition") ||
                  button_texts.index("Planning Permit Applications Advertised") ||
                  button_texts.index("Development applications in Public Notification") ||
                  button_texts.index("Advertised Planning Applications") ||
                  button_texts.index("Planning Applications Currently Advertised") ||
                  button_texts.index("Planning permit applications advertised") ||
                  button_texts.index("Planning applications being advertised")
              elsif type == :all
                button_texts.index("Development Application Tracking") ||
                  button_texts.index("Town Planning Public Register") ||
                  button_texts.index("Planning Application Register") ||
                  button_texts.index("Planning Permit Application Search") ||
                  button_texts.index("Development applications") ||
                  button_texts.index("Development Applications")
              else
                raise "Unexpected list type: #{type}"
              end
      raise "Couldn't find index for #{type} in #{button_texts}" if index.nil?

      form.radiobuttons[index].click
      form.submit(form.button_with(value: /Next/))
    end

    # list_type one of :advertising, :all, :last_30_days
    def pick_type_of_search(list_type)
      page = agent.get(base_url)

      # Checking whether we're on the right page
      unless page.search('input[type="radio"]').empty?
        page = pick_type_of_application(page, list_type)
      end

      if list_type == :last_30_days
        # Fake that we're running javascript by picking out the javascript redirect
        redirected_url = page.body.match(/window.location.href='(.*)';/)[1]
        page = agent.get(redirected_url)

        page = click_date_search_tab(page)
        # The Date tab defaults to a search range of the last 30 days.
        page = click_search_on_page(page)
      end
      page
    end

    def scrape_index_page(page)
      table = page.at("table.ContentPanel")
      return if table.nil?

      extract_table_data_and_urls(table).each do |row|
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

    # This scrapes all index pages by doing GETs on each page
    def scrape_all_index_pages_with_gets(number_pages)
      page = agent.get("EnquirySummaryView.aspx?PageNumber=1")
      number_pages ||= extract_total_number_of_pages(page)
      (1..number_pages).each do |no|
        page = agent.get("EnquirySummaryView.aspx?PageNumber=#{no}") if no > 1
        scrape_index_page(page) do |record|
          yield record
        end
      end
    end

    # This scrapes all index pages by clicking the next link
    # with all the POSTback nonsense
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

    # TODO: max_pages is currently ignored if with_gets is false
    def scrape(list_type:, with_gets: false, max_pages: nil)
      # Navigate to the correct list
      page = pick_type_of_search(list_type)
      if with_gets
        # Notice how we're skipping the clicking of search
        # even though that's what the user interface is showing next
        scrape_all_index_pages_with_gets(max_pages) do |record|
          yield record
        end
      else
        page = click_search_on_page(page)

        # And scrape everything
        scrape_all_index_pages(page) do |record|
          yield record
        end
      end
    end

    private

    def field(page, name)
      span = page.at("span:contains(\"#{name}\")")
      span.next.inner_text.to_s.strip if span
    end
  end
end
