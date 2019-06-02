# frozen_string_literal: true

require "epathway_scraper/table"

module EpathwayScraper
  module Page
    # The detail page that shows all the information about the application
    # Hopefully we don't have to look at this page because the index page
    # has the information we need
    module Detail
      def self.scrape(detail_page)
        address = field(detail_page, "Application location")
        # If address is stored in a table at the bottom
        if address.nil?
          # Find the table that contains the addresses
          table = detail_page.search("table.ContentPanel").find do |t|
            k = Table.extract_table_data_and_urls(t)[0][:content].keys
            k.include?("Property Address") || k.include?("Address")
          end
          raise "Couldn't find address table" if table.nil?

          rows = Table.extract_table_data_and_urls(table)
          # If there's just one location then use that
          row = if rows.count == 1
                  rows[0]
                # Otherwise find the address of the primary location
                else
                  rows.find { |r| r[:content]["Primary Location"] == "Yes" }
                end
          raise "Couldn't find primary address" if row.nil?

          address = row[:content]["Property Address"] || row[:content]["Address"]
        end

        date_received = field(detail_page, "Date Received") ||
                        field(detail_page, "Lodgement date") ||
                        field(detail_page, "Lodgement Date")

        on_notice_table = detail_page.search("table.ContentPanel").find do |t|
          k = Table.extract_table_data_and_urls(t)[0][:content].keys
          k.include?("Start Date")
        end

        if on_notice_table
          data = Table.extract_table_data_and_urls(on_notice_table)
          on_notice_from = Date.strptime(data[0][:content]["Start Date"], "%d/%m/%Y").to_s
          on_notice_to = Date.strptime(data[0][:content]["Closing Date"], "%d/%m/%Y").to_s
        end

        {
          council_reference: field(detail_page, "Application Number") ||
            field(detail_page, "Application number"),
          description: field(detail_page, "Proposed Use or Development") ||
            field(detail_page, "Application description") ||
            field(detail_page, "Proposal"),
          date_received: Date.strptime(date_received, "%d/%m/%Y").to_s,
          address: address,
          on_notice_from: on_notice_from,
          on_notice_to: on_notice_to
        }
      end

      def self.field(page, name)
        span = page.at("span:contains(\"#{name}\")")
        span.next.inner_text.to_s.strip if span
      end
    end
  end
end
