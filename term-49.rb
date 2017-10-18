#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

POSITION_HELD = 'P39'
START_DATE = 'P580'
END_DATE = 'P582'
CONSTITUENCY = 'P768'
PARTY = 'P4100'
ELECTED_IN = 'P2715'
TERM = 'P2937'
SOURCE = 'S854'

def wikidate(str)
  return unless str
  '+%sT00:00:00Z/11' % str
end

def quoted(str)
  '"%s"' % str.to_s
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class MemberList < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    member_rows.map { |tr| fragment(tr => MemberRow) }
  end

  private

  def members_table
    noko.xpath('//h2[span[text()="By-elections during 49th Parliament"]]/following::*').remove
    noko.xpath('//h2[span[text()="Members of the 49th New Zealand Parliament"]]/following-sibling::table')
  end

  def member_rows
    members_table.xpath('.//tr[td[3]]')
  end
end

class MemberRow < Scraped::HTML
  field :id do
    member.attr('wikidata')
  end

  field :name do
    member.text.tidy
  end

  field :area_id do
    electorate&.attr('wikidata')
  end

  field :area do
    electorate&.text&.tidy
  end

  field :party_id do
    group&.attr('wikidata')
  end

  field :party do
    group&.text&.tidy
  end

  private

  def td
    noko.css('td')
  end

  def group
    noko.xpath('preceding::h3').last.css('a').first
  end

  def member
    td[1].css('a').first
  end

  def electorate
    td[2].css('a').first
  end
end

url = 'https://en.wikipedia.org/wiki/49th_New_Zealand_Parliament'

MEMBERSHIP = 'Q18145518' # Member of the NZ HoR
TERM_ID    = 'Q11812120' # 49th Parliament
ELECTION   = 'Q1366881'  # 2008 election
SOURCE_URL = url

TERM_START = wikidate('2008-12-08')
TERM_END   = wikidate('2011-10-20')

page = scraper(url => MemberList)

instructions = page.members.map do |mem|
  data = {
    POSITION_HELD => MEMBERSHIP,
    TERM          => TERM_ID,
    START_DATE    => TERM_START,
    END_DATE      => TERM_END,
    PARTY         => mem.party_id,
    CONSTITUENCY  => mem.area_id,
    ELECTED_IN    => ELECTION,
    SOURCE        => quoted(SOURCE_URL),
  }.compact.to_a
  [mem.id, data].join("\t")
end

puts instructions
