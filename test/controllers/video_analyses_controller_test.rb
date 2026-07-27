# 영상 기획 분석 엔드포인트 — stub 생성·캐시 재사용·404 검증(실 yt-dlp·Gemini 호출 없음)
require "test_helper"

class VideoAnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @ch = Channel.create!(name: "채널", category: "직접경쟁", source: "seed", is_own: false)
    @video = @ch.videos.create!(youtube_video_id: "vid_abc", title: "테스트 영상", view_count: 100)
  end

  test "GET analysis 는 stub 로 생성해 ok JSON 을 반환하고 캐시한다" do
    assert_difference "VideoAnalysis.count", 1 do
      get video_analysis_path(@video)
    end
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "ok", body["status"]
    assert body["intro_excerpt"].present?
    assert body["overall_analysis"].present?
    assert_equal "테스트 영상", body["title"]
    assert_includes body["url"], "youtube.com"
  end

  test "두 번째 요청은 캐시를 써 재생성하지 않는다" do
    get video_analysis_path(@video)
    assert_no_difference "VideoAnalysis.count" do
      get video_analysis_path(@video)
    end
    assert_response :success
  end

  test "없는 영상은 404" do
    get video_analysis_path(id: 999_999)
    assert_response :not_found
  end
end
