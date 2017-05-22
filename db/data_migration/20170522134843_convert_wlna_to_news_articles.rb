def update_db_records_to_news_article(editions)
  editions.update_all(
    type: "NewsArticle",
    news_article_type_id: NewsArticleType::WorldNewsStory.id
  )
end

def update_rummager(editions)
  editions.each(&:save)
end

def editions_including_deleted(document_id)
  Edition.unscoped.where(document_id: document_id)
end

world_location_news_articles = WorldLocationNewsArticle.all
wlna_documents = Document.where(id: world_location_news_articles.pluck(:document_id).uniq)

puts "Migrating #{wlna_documents.count} WLNA -> NewsArticle"

wlna_documents.each do |wlna_document|
  begin
    #updating sluggable_string will regenerate the slug and  de-duplicate
    #if there is already a news article with this slug
    wlna_document.update_attributes(
      document_type: "NewsArticle",
      sluggable_string: wlna_document.slug
    )
  rescue ActiveRecord::RecordNotUnique
    puts "NotUnique: #{wlna_document.id}"
  end

  editions = editions_including_deleted(wlna_document.id)

  update_db_records_to_news_article(editions)
  update_rummager(editions)

  PublishingApiDocumentRepublishingWorker.perform_async_in_queue("bulk_republishing", wlna_document.id)

  print "."
end
