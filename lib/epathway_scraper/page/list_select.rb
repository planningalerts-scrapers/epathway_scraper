# frozen_string_literal: true

module EpathwayScraper
  module Page
    # The first page you come to on the site where you can usually choose between
    # something like "development applications" and applications that are on notice.
    # If there is only one type of list then it looks like this page can be absent
    module ListSelect
      ADVERTISING_TEXT = [
        "advertised planning applications",
        "applications on exhibition",
        "development applications on public exhibition",
        "development applications in public notification",
        "planning application at advertising",
        "planning applications being advertised",
        "planning applications currently on advertising",
        "planning applications currently advertised",
        "planning permit applications advertised"
      ].freeze

      ALL_TEXT = [
        "development application tracking",
        "development applications",
        "find a development application",
        "list of development applications",
        "planning application enquiry",
        "planning application register",
        "planning permit application search",
        "town planning public register",
        # This one is ridiculous
        "the barossa council development applications"
      ].freeze

      def self.select(page, text_to_match)
        form = page.forms.first

        button_texts = page.search('input[type="radio"]').map do |i|
          # Make the text lowercase for easier matching
          i.parent.next.inner_text.downcase
        end

        index = button_texts.find_index { |text| text_to_match.include?(text) }
        raise "Couldn't find index in #{button_texts}" if index.nil?

        form.radiobuttons[index].click
        button = form.button_with(value: /Next/) || form.button_with(value: /Save and Continue/)
        raise "Couldn't find button" if button.nil?

        form.submit(button)
      end

      def self.select_advertising(page)
        select(page, ADVERTISING_TEXT)
      end

      def self.select_all(page)
        select(page, ALL_TEXT)
      end

      # Fake that we're running javascript by picking out the javascript redirect
      def self.follow_javascript_redirect(page, agent)
        match = page.body.match(/window.location.href='(.*)';/)
        raise "Could not find javascript redirect" if match.nil?

        redirected_url = match[1]
        agent.get(redirected_url)
      end

      # Very simple minded test for whether we're on the correct page
      def self.on_page?(page)
        !page.search('input[type="radio"]').empty?
      end
    end
  end
end
