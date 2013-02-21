require "fetcher"
class NewsItem < ActiveRecord::Base
  belongs_to :source
  validates_uniqueness_of :guid, scope: [:source_id]

  scope :home_page, -> {
    order("value desc").where("value is not null")
  }

  include FetcherConcern

  def self.process(entry)
    return NewsItem.new if entry[:published] < 10.days.ago
    guid = entry[:guid][0..240]
    old = entry[:source].news_items.where(guid: guid).first
    item = old || NewsItem.new( guid: guid)
    if item.new_record?
      if entry[:source].name["Personalmagazin"]
        item.url = entry[:url]
      else
        item.url = Fetcher.real_url(entry[:url])
      end
      item.source = entry[:source]
      item.published_at = entry[:published]
    end
    item.assign_attributes(
      teaser: teaser(entry[:text]),
      title: entry[:title],
    )
    item.save
    item
  end

  def self.cronjob
    NewsItem.old.destroy_all
    NewsItem.find_each do |item|
      item.refresh
    end
  end

  def self.teaser(text)
    ActionController::Base.helpers.truncate Nokogiri::HTML.fragment(text).text,
      length: 255
  end


  def refresh
    fetch_linkedin
    fetch_twitter
    fetch_facebook
    fetch_xing
    fetch_gplus
    self.value = score
    save
  end

end
