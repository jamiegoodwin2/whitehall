namespace :worldwide_taxonomy do
  task redirect_world_location_translations_to_en: :environment do
    redirect_world_locations("/government/world", [:en])
  end

  task redirect_all_world_locations_to_taxon_base_path: :environment do
    redirect_world_locations("/world")
  end

  def redirect_world_locations(base_path_prefix, locales_to_exclude = [])
    world_locations = WorldLocation.all
    world_locations.each do |world_location|
      en_slug = world_location.slug
      destination_base_path = File.join("", base_path_prefix, en_slug)
      content_id = world_location.content_id
      locales = world_location.original_available_locales.reject do |locale|
        locales_to_exclude.include?(locale)
      end

      locales.each do |locale|
        PublishingApiRedirectWorker.perform_async_in_queue(
          "bulk_republishing",
          content_id,
          destination_base_path,
          locale
        )
      end
    end
  end
end
