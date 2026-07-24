# 인기 콘텐츠 뷰 — 밴드 그룹/평면 렌더·스파크라인 콜드스타트·자사 유사 뱃지 3종·youtube 링크 검증
require "test_helper"

class PopularViewTest < ActionView::TestCase
  def make_scored(title:, subscriber_count: 50_000, own_match_count: 0, multiple: 4.0, daily: 0)
    channel = Channel.create!(name: "채널 #{SecureRandom.hex(2)}", category: "직접경쟁", source: "seed", subscriber_count: subscriber_count)
    video = channel.videos.create!(
      youtube_video_id: "vr_#{SecureRandom.hex(4)}",
      title: title, view_count: 54_321, is_short: false, published_at: Time.utc(2026, 5, 1), thumbnail: "https://example.com/t.jpg"
    )
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: own_match_count, needs_verification: false, rank_eligible: true)
    daily.times { |d| video.daily_stats.create!(date: Date.new(2026, 5, 1) + d, view_count: 100 + d * 10) }
    video.reload
  end

  def render_index(scores:, grouped:, layout:)
    # ActionView::TestCase 는 테스트 인스턴스 변수를 뷰로 복사한다.
    @scores = scores
    @grouped = grouped
    @period = "1w"
    @category = "all"
    @type = "all"
    @layout = layout
    render template: "popular/index", layout: false
  end

  test "평면 레이아웃은 행을 순번과 함께 렌더한다" do
    v = make_scored(title: "평면 영상")
    scores = VideoScore.where(video: v).to_a
    render_index(scores: scores, grouped: nil, layout: "flat")
    assert_includes rendered, "평면 영상"
    assert_includes rendered, "인기 콘텐츠"
  end

  test "밴드 레이아웃은 밴드 그룹 헤더와 행을 렌더한다" do
    v = make_scored(title: "밴드 영상", subscriber_count: 50_000)
    scores = VideoScore.where(video: v).to_a
    grouped = scores.group_by { |s| s.video.channel.subscriber_band }.sort_by { |b, _| b.nil? ? 4 : b }
    render_index(scores: scores, grouped: grouped, layout: "band")
    assert_includes rendered, "밴드 영상"
    assert_includes rendered, "1만~10만" # 밴드 그룹 헤더 라벨
  end

  test "스파크라인 스냅샷 부족 시 데이터 수집 중 자리 유지" do
    video = make_scored(title: "콜드 영상", daily: 0)
    render partial: "shared/video_row", locals: { video: video, rank: 1, sparkline: true }
    assert_includes rendered, "데이터 수집 중"
    assert_not_includes rendered, "<polyline"
  end

  test "스파크라인 스냅샷 충분 시 polyline 렌더" do
    video = make_scored(title: "따뜻한 영상", daily: 7)
    render partial: "shared/video_row", locals: { video: video, rank: 1, sparkline: true }
    assert_includes rendered, "<polyline"
    assert_includes rendered, "text-primary-600"
  end

  test "자사 유사 뱃지 0/1/2 klass" do
    render partial: "shared/video_row", locals: { video: make_scored(title: "없음", own_match_count: 0) }
    assert_includes rendered, "bg-badge-neutralBg"
    render partial: "shared/video_row", locals: { video: make_scored(title: "하나", own_match_count: 1) }
    assert_includes rendered, "bg-badge-cautionBg"
    render partial: "shared/video_row", locals: { video: make_scored(title: "둘", own_match_count: 2) }
    assert_includes rendered, "bg-badge-dangerBg"
  end

  test "영상 셀은 youtube watch 링크를 담는다" do
    video = make_scored(title: "링크 영상")
    render partial: "shared/video_row", locals: { video: video }
    assert_includes rendered, "https://www.youtube.com/watch?v=#{video.youtube_video_id}"
    assert_includes rendered, "target=\"_blank\""
  end
end
