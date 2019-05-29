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
    end
  end
end
