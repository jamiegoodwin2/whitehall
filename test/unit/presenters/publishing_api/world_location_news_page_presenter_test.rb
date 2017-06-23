require 'test_helper'

class PublishingApi::WorldLocationNewsPagePresenterTest < ActiveSupport::TestCase
  def present(model_instance)
    PublishingApi::WorldLocationNewsPagePresenter.new(model_instance, {})
  end

  test 'with an item not yet in the publishing api, it presents a World Location News Page ready for publishing api' do
    wl = create(:world_location, name: "Aardistan", title: "Aardistan and the Uk")

    expected_hash = {
      title: "Aardistan and the Uk",
      locale: "en",
      need_ids: [],
      publishing_app: "whitehall",
      redirects: [],
      description: "Updates, news and events from the UK government in Aardistan",
      details: {},
      document_type: "special_route",
      public_updated_at: wl.updated_at,
      rendering_app: "whitehall-frontend",
      schema_name: "placeholder",
      base_path: "/government/world/aardistan/news",
      routes: [{ path:  "/government/world/aardistan/news", type: "exact" }],
      analytics_identifier: "WL1",
    }

    Services.publishing_api.stubs(:lookup_content_ids).returns({})

    PublishingApi::WorldLocationNewsPagePresenter.any_instance.stubs(:content_id).returns("a_new_guid")

    presented_item = present(wl)

    assert_equal expected_hash, presented_item.content
    assert_equal "a_new_guid", presented_item.content_id
  end

  test 'with an item already in the publishing api, it presents a World Location News Page ready for publishing api' do
    wl = create(:world_location, name: "Aardistan", title: "Aardistan and the Uk")

    expected_hash = {
      title: "Aardistan and the Uk",
      locale: "en",
      need_ids: [],
      publishing_app: "whitehall",
      redirects: [],
      description: "Updates, news and events from the UK government in Aardistan",
      details: {},
      document_type: "special_route",
      public_updated_at: wl.updated_at,
      rendering_app: "whitehall-frontend",
      schema_name: "placeholder",
      base_path: "/government/world/aardistan/news",
      routes: [{ path: "/government/world/aardistan/news", type: "exact" }],
      analytics_identifier: "WL1",
    }

    Services.publishing_api.stubs(:lookup_content_ids).returns("/government/world/aardistan/news" => "aguid")

    presented_item = present(wl)

    assert_equal expected_hash, presented_item.content
    assert_equal "aguid", presented_item.content_id
  end
end
