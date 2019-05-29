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
    end
  end
end
