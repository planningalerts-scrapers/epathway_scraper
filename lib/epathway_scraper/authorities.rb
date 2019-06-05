# frozen_string_literal: true

module EpathwayScraper
  # The settings to scrape each different authority
  AUTHORITIES = {
    adelaide: {
      url: "https://epathway.adelaidecitycouncil.com/epathway/ePathwayProd",
      state: "SA",
      list: :all_this_year
    },
    ballarat: {
      url: "https://eservices.ballarat.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :advertising
    },
    barossa: {
      url: "https://epayments.barossa.sa.gov.au/ePathway/Production",
      state: "SA",
      list: :last_30_days,
      force_detail: true
    },
    campbelltown: {
      url: "https://ebiz.campbelltown.nsw.gov.au/ePathway/Production",
      state: "NSW",
      list: :all
    },
    darebin: {
      url: "https://eservices.darebin.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :all_this_year
    },
    glen_eira: {
      url: "https://epathway-web.gleneira.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :all,
      max_pages: 4
    },
    gold_coast: {
      url: "https://cogc.cloud.infor.com/ePathway/epthprod",
      state: "QLD",
      list: :advertising
    },
    greatlakes: {
      url: "https://services.greatlakes.nsw.gov.au/ePathway/Production",
      state: "NSW",
      list: :all,
      max_pages: 10
    },
    inverell: {
      url: "http://203.49.140.77/ePathway/Production",
      state: "NSW",
      list: :all_this_year
    },
    kingston: {
      url: "https://online.kingston.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :all_this_year
    },
    knox: {
      url: "https://eservices.knox.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :advertising
    },
    monash: {
      url: "https://epathway.monash.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :advertising
    },
    moreland: {
      url: "https://eservices.moreland.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :advertising
    },
    nillumbik: {
      url: "https://epathway.nillumbik.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :advertising
    },
    onkaparinga: {
      url: "http://pathway.onkaparinga.sa.gov.au/ePathway/Production",
      state: "SA",
      list: :all_this_year
    },
    salisbury: {
      url: "https://eservices.salisbury.sa.gov.au/ePathway/Production",
      state: "SA",
      list: :last_30_days
    },
    south_gippsland: {
      url: "https://eservices.southgippsland.vic.gov.au/ePathway/ePathProd",
      state: "VIC",
      list: :advertising
    },
    the_hills: {
      url: "https://epathway.thehills.nsw.gov.au/ePathway/Production",
      state: "NSW",
      list: :last_30_days
    },
    unley: {
      url: "https://online.unley.sa.gov.au/ePathway/Production",
      state: "SA",
      list: :last_30_days
    },
    west_torrens: {
      url: "https://epathway.wtcc.sa.gov.au/ePathway/Production",
      state: "SA",
      list: :last_30_days
    },
    wollongong: {
      url: "http://epathway.wollongong.nsw.gov.au/ePathway/Production",
      state: "NSW",
      list: :advertising
    },
    yarra_ranges: {
      url: "https://epathway.yarraranges.vic.gov.au/ePathway/Production",
      state: "VIC",
      list: :all,
      max_pages: 20
    }
  }.freeze
end
