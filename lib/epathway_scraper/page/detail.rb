# frozen_string_literal: true

require "epathway_scraper/table"

module EpathwayScraper
  module Page
    # The detail page that shows all the information about the application
    # Hopefully we don't have to look at this page because the index page
    # has the information we need
    module Detail
      def self.scrape(detail_page, base_url)
        address = field(detail_page, "Application location")
        # If address is stored in a table at the bottom
        if address.nil?
          # Find the table that contains the addresses
          table = detail_page.search("table.ContentPanel").find do |t|
            Table.extract_table_data_and_urls(t, base_url)[0][:content].keys.include?(
              "Property Address"
            )
          end
          # Find the address of the primary location
          row = Table.extract_table_data_and_urls(table, base_url).find do |r|
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

      def self.field(page, name)
        span = page.at("span:contains(\"#{name}\")")
        span.next.inner_text.to_s.strip if span
      end
    end
  end
end
