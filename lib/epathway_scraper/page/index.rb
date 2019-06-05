# frozen_string_literal: true

require "epathway_scraper/table"
require "epathway_scraper/page/detail"

require "English"

module EpathwayScraper
  module Page
    # A list of applications (probably paginated)
    module Index
      DATE_RECEIVED_TEXT = [
        "application date",
        "date",
        "date lodged",
        "date received",
        "date registered",
        "lodged",
        "lodge date",
        "lodgement date"
      ].freeze

      COUNCIL_REFERENCE_TEXT = [
        "app no.",
        "application",
        "application no",
        "application number",
        "number",
        "our reference"
      ].freeze

      DESCRIPTION_TEXT = [
        "application description",
        "application proposal",
        "description",
        "details of proposal or permit",
        "proposal",
        "proposed use or development"
      ].freeze

      ADDRESS_TEXT = [
        "address",
        "application location",
        "location",
        "location address",
        "primary property address",
        "property address",
        "site address",
        "site location"
      ].freeze

      SUBURB_TEXT = [
        "suburb"
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

      def self.find_value_by_key(row, key_matches)
        # Matching using lowercase letters to make things simpler
        r = row[:content].find { |k, _v| key_matches.include?(k.downcase) }
        r[1] if r
      end

      def self.extract_index_data(row)
        date_received = find_value_by_key(row, DATE_RECEIVED_TEXT)
        date_received = Date.strptime(date_received, "%d/%m/%Y").to_s if date_received

        address = find_value_by_key(row, ADDRESS_TEXT)
        suburb = find_value_by_key(row, SUBURB_TEXT)

        # Add the suburb to addresses that don't already include them
        address += ", #{suburb}" if suburb && !address.include?(suburb)

        {
          council_reference: find_value_by_key(row, COUNCIL_REFERENCE_TEXT),
          address: address,
          description: find_value_by_key(row, DESCRIPTION_TEXT),
          date_received: date_received,
          # This URL will only work in a session. Thanks for that!
          detail_url: row[:url]
        }
      end

      # If force_detail is true, then we always scrape the detail page
      # We need this for the case of Barossa, SA that doesn't include the
      # suburb in the address on the index page. We don't have a simple and
      # reliable way to automatically detect this
      def self.scrape_index_page(page, base_url, agent, force_detail, state)
        table = page.at("table.ContentPanel")
        return if table.nil?

        Table.extract_table_data_and_urls(table).each do |row|
          data = extract_index_data(row)

          # Check if we have all the information we need from the index_data
          # If so then there's no need to scrape the detail page
          unless data[:council_reference] &&
                 data[:address] &&
                 data[:description] &&
                 data[:date_received] &&
                 !force_detail

            # Get application page with a referrer or we get an error page
            detail_page = agent.get(data[:detail_url], [], page.uri)

            data = data.merge(Detail.scrape(detail_page))

            # Finally check we have everything
            unless data[:council_reference] &&
                   data[:address] &&
                   data[:description] &&
                   data[:date_received]
              raise "Couldn't get all the data"
            end
          end

          # Remove "building name" from address
          if data[:address].split(",").size >= 3
            data[:address] = data[:address].split(",", 2)[1].strip
          end

          # Add state to the end of the address if it isn't already there
          data[:address] += ", #{state}" unless data[:address].include?(state)

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
      def self.scrape_all_index_pages(number_pages, base_url, agent, force_detail, state)
        page = agent.get("EnquirySummaryView.aspx?PageNumber=1")
        number_pages ||= extract_total_number_of_pages(page)
        (1..number_pages).each do |no|
          page = agent.get("EnquirySummaryView.aspx?PageNumber=#{no}") if no > 1
          scrape_index_page(page, base_url, agent, force_detail, state) do |record|
            yield record
          end
        end
      end
    end
  end
end
