# frozen_string_literal: true

module EpathwayScraper
  module Page
    # Usually the second page on the site where you do an actual search.
    # It has a tab interface usually for different kinds of searches
    module Search
      def self.click_date_search_tab(page, agent)
        table = page.at("table.tabcontrol")
        href = table.search("a").find { |a| a.inner_text == "Date Search" }["href"]
        # Extract target and argument of postback from href
        match = href.match(/javascript:__doPostBack\('(.*)','(.*)'\)/)
        raise "Link isn't a postback link" if match.nil?

        form = page.forms.first
        raise "Can't find form for postback" if form.nil?

        form["__EVENTTARGET"] = match[1]
        form["__EVENTARGUMENT"] = match[2]
        agent.submit(form)
      end

      def self.search_for_one_application(page, application_no)
        form = page.form
        field = form.field_with(name: /FormattedNumberTextBox/)
        field.value = application_no
        button = form.button_with(value: "Search")
        form.submit(button)
      end
    end
  end
end
