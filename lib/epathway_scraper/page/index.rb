# frozen_string_literal: true

require "epathway_scraper/table"
require "epathway_scraper/page/detail"

require "English"

module EpathwayScraper
  module Page
    # A list of applications (probably paginated)
    module Index
      DATE_RECEIVED_TEXT = [
        "Date Lodged",
        "Date lodged",
        "Application Date",
        "Application date",
        "Lodgement Date",
        "Date received",
        "Date",
        "Lodged",
        "Date Registered",
        "Lodge Date"
      ].freeze

      COUNCIL_REFERENCE_TEXT = [
        "App No.",
        "Application Number",
        "Application number",
        "Number",
        "Our Reference",
        "Application No",
        "Application"
      ].freeze

      DESCRIPTION_TEXT = [
        "Proposed Use or Development",
        "Description",
        "Application Proposal",
        "Proposal",
        "Application Description",
        "Application proposal",
        "Details of proposal or permit"
      ].freeze

      ADDRESS_TEXT = [
        "Location Address",
        "Property Address",
        "Site Location",
        "Application location",
        "Application Location",
        "Location",
        "Primary Property Address",
        "Site Address",
        "Address"
      ].freeze

      SUBURB_TEXT = [
        "Suburb"
      ].freeze

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
        date_received = row[:content].find { |k, _v| DATE_RECEIVED_TEXT.include?(k) }
        date_received = date_received[1] if date_received
        date_received = Date.strptime(date_received, "%d/%m/%Y").to_s if date_received

        council_reference = row[:content].find { |k, _v| COUNCIL_REFERENCE_TEXT.include?(k) }
        council_reference = council_reference[1] if council_reference

        address = row[:content].find { |k, _v| ADDRESS_TEXT.include?(k) }
        address = address[1] if address

        suburb = row[:content].find { |k, _v| SUBURB_TEXT.include?(k) }
        suburb = suburb[1] if suburb

        # If suburb is not in the address then add it
        if suburb && !address.include?(suburb)
          # TODO: Remove hardcoded state here
          address += ", #{suburb}, VIC"
        end

        description = row[:content].find { |k, _v| DESCRIPTION_TEXT.include?(k) }
        description = description[1] if description

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

        Table.extract_table_data_and_urls(table).each do |row|
          data = extract_index_data(row)

          # Check if we have all the information we need from the index_data
          # If so then there's no need to scrape the detail page
          unless data[:council_reference] &&
                 data[:address] &&
                 data[:description] &&
                 data[:date_received]

            # Get application page with a referrer or we get an error page
            detail_page = agent.get(data[:detail_url], [], page.uri)

            data = Detail.scrape(detail_page)
          end

          record = {
            "council_reference" => data[:council_reference],
            "address" => data[:address],
            "description" => data[:description],
            "info_url" => base_url,
            "date_scraped" => Date.today.to_s,
            "date_received" => data[:date_received]
          }
          record["on_notice_from"] = data[:on_notice_from] if data[:on_notice_from]
          record["on_notice_to"] = data[:on_notice_to] if data[:on_notice_to]
          yield(record)
        end
      end

      # This scrapes all index pages by doing GETs on each page
      def self.scrape_all_index_pages(number_pages, base_url, agent)
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
