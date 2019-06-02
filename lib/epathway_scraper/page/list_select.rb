# frozen_string_literal: true

module EpathwayScraper
  module Page
    # The first page you come to on the site where you can usually choose between
    # something like "development applications" and applications that are on notice.
    # If there is only one type of list then it looks like this page can be absent
    module ListSelect
      # type can be either :advertising or :all
      def self.pick(page, type)
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
                    button_texts.index("Development Applications") ||
                    button_texts.index("Planning Application Enquiry") ||
                    button_texts.index("List of Development Applications")
                else
                  raise "Unexpected list type: #{type}"
                end
        raise "Couldn't find index for #{type} in #{button_texts}" if index.nil?

        form.radiobuttons[index].click
        form.submit(form.button_with(value: /Next/))
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
