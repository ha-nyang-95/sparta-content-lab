# VideoAttributes.from — duration 초 파싱·통계 누락 nil 방어·published_at·thumbnail·불량 duration 방어 검증
require "test_helper"

class Youtube::VideoAttributesTest < ActiveSupport::TestCase
  def item(overrides = {})
    {
      "id" => "vid_x",
      "snippet" => {
        "title" => "제목",
        "publishedAt" => "2026-07-20T09:00:00Z",
        "thumbnails" => { "medium" => { "url" => "https://i.ytimg.com/vi/vid_x/mq.jpg" } }
      },
      "statistics" => { "viewCount" => "1234", "likeCount" => "56", "commentCount" => "7" },
      "contentDetails" => { "duration" => "PT4M13S" }
    }.deep_merge(overrides)
  end

  test "duration PT4M13S 는 253초" do
    assert_equal 253, Youtube::VideoAttributes.from(item)[:duration]
  end

  test "duration PT58S 는 58초" do
    attrs = Youtube::VideoAttributes.from(item("contentDetails" => { "duration" => "PT58S" }))
    assert_equal 58, attrs[:duration]
  end

  test "viewCount 누락은 view_count nil" do
    it = item
    it["statistics"] = { "likeCount" => "1", "commentCount" => "2" }
    assert_nil Youtube::VideoAttributes.from(it)[:view_count]
  end

  test "likeCount/commentCount 누락은 nil(방어)" do
    it = item
    it["statistics"] = { "viewCount" => "10" }
    attrs = Youtube::VideoAttributes.from(it)
    assert_nil attrs[:like_count]
    assert_nil attrs[:comment_count]
    assert_equal 10, attrs[:view_count]
  end

  test "publishedAt 은 Time 으로 파싱" do
    published = Youtube::VideoAttributes.from(item)[:published_at]
    assert_kind_of Time, published
    assert_equal Time.utc(2026, 7, 20, 9, 0, 0), published
  end

  test "thumbnail url 추출" do
    assert_equal "https://i.ytimg.com/vi/vid_x/mq.jpg", Youtube::VideoAttributes.from(item)[:thumbnail]
  end

  test "불량/누락 duration 은 nil(raise 없음)" do
    assert_nil Youtube::VideoAttributes.from(item("contentDetails" => { "duration" => "쓰레기" }))[:duration]
    it = item
    it["contentDetails"] = {}
    assert_nil Youtube::VideoAttributes.from(it)[:duration]
  end

  test "P0D(라이브)는 0, 음수 duration 은 nil 로 파싱한다" do
    assert_equal 0, Youtube::VideoAttributes.parse_duration("P0D")
    assert_equal 0, Youtube::VideoAttributes.parse_duration("PT0S")
    assert_nil Youtube::VideoAttributes.parse_duration("-PT5M")
    assert_nil Youtube::VideoAttributes.parse_duration("쓰레기")
    assert_nil Youtube::VideoAttributes.parse_duration(nil)
  end

  test "썸네일은 medium 우선, 없으면 standard/maxres 로 폴백한다" do
    only_maxres = { "maxres" => { "url" => "http://x/maxres.jpg" } }
    assert_equal "http://x/maxres.jpg", Youtube::VideoAttributes.thumbnail_url(only_maxres)
    assert_nil Youtube::VideoAttributes.thumbnail_url({})
  end

end
