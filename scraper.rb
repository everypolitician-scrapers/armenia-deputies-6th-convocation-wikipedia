#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    member_rows.map do |row|
      mem = fragment(row => MemberRow)
      faction = factions[mem.faction_colour].first
      mem.to_h.merge(faction: faction.name, faction_id: faction.id)
    end
  end

  field :factions do
    @factions ||= faction_rows.map { |row| fragment(row => FactionRow) }.group_by(&:colour)
  end

  private

  def member_table
    noko.xpath('//table[.//th[contains(., "№")]]')
  end

  def member_rows
    member_table.xpath('.//tr[td]')
  end

  def faction_rows
    member_table.xpath('preceding::dl//following-sibling::p')
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :faction_colour do
    noko.at_css('th').attr('style')[/background:#(\w+)/, 1]
  end

  private

  def tds
    noko.css('td')
  end
end

class FactionRow < Scraped::HTML
  field :name do
    noko.css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    noko.css('a/@wikidata').map(&:text).first
  end

  field :colour do
    noko.at_css('span').attr('style')[/background-color:\s?#(\w+)/, 1]
  end
end

url = URI.encode 'https://hy.wikipedia.org/wiki/ՀՀ_ԱԺ_6-րդ_գումարման_պատգամավորների_ցանկ'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name faction])
