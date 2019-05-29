# frozen_string_literal: true

module EpathwayScraper
  # Helper methods for getting stuff out of tables in epathway
  module Table
    # Also include the urls of links
    # TODO: Should we just return relative urls then we don't need to pass base_url?
    def self.extract_table_data_and_urls(table, base_url)
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
  end
end
