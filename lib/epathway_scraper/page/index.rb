# frozen_string_literal: true

module EpathwayScraper
  module Page
    # A list of applications (probably paginated)
    module Index
      def self.extract_total_number_of_pages(page)
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

      def self.extract_index_data(row)
        date_received = row[:content]["Date Lodged"] ||
                        row[:content]["Date lodged"] ||
                        row[:content]["Application Date"] ||
                        row[:content]["Application date"] ||
                        row[:content]["Lodgement Date"] ||
                        row[:content]["Date received"] ||
                        row[:content]["Date"]
        date_received = Date.strptime(date_received, "%d/%m/%Y").to_s if date_received

        council_reference = row[:content]["App No."] ||
                            row[:content]["Application Number"] ||
                            row[:content]["Application number"]

        address = row[:content]["Location Address"] ||
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
                  row[:content]["Address"]

        description = row[:content]["Proposed Use or Development"] ||
                      row[:content]["Description"] ||
                      row[:content]["Application Proposal"] ||
                      row[:content]["Proposal"] ||
                      row[:content]["Application Description"] ||
                      row[:content]["Application proposal"]

        {
          council_reference: council_reference,
          address: address,
          description: description,
          date_received: date_received,
          # This URL will only work in a session. Thanks for that!
          detail_url: row[:url]
        }
      end

      def self.scrape_index_page(page, base_url, agent)
        table = page.at("table.ContentPanel")
        return if table.nil?

        Table.extract_table_data_and_urls(table, base_url).each do |row|
          data = extract_index_data(row)

          # Check if we have all the information we need from the index_data
          # If so then there's no need to scrape the detail page
          unless data[:council_reference] &&
                 data[:address] &&
                 data[:description] &&
                 data[:date_received]

            # Get application page with a referrer or we get an error page
            detail_page = agent.get(data[:detail_url], [], page.uri)

            data = Page::Detail.scrape(detail_page, base_url)
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

      def self.click_next_page_link(page, page_no, agent)
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

      # This scrapes all index pages by clicking the next link
      # with all the POSTback nonsense
      def self.scrape_all_index_pages(page, base_url, agent)
        page_no = 1
        loop do
          scrape_index_page(page, base_url, agent) do |record|
            yield record
          end

          page = Page::Index.click_next_page_link(page, page_no, agent)
          break if page.nil?

          page_no += 1
        end
      end

      # This scrapes all index pages by doing GETs on each page
      def self.scrape_all_index_pages_with_gets(number_pages, base_url, agent)
        page = agent.get("EnquirySummaryView.aspx?PageNumber=1")
        number_pages ||= extract_total_number_of_pages(page)
        (1..number_pages).each do |no|
          page = agent.get("EnquirySummaryView.aspx?PageNumber=#{no}") if no > 1
          scrape_index_page(page, base_url, agent) do |record|
            yield record
          end
        end
      end
    end
  end
end
