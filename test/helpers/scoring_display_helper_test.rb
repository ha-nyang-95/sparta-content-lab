# ScoringDisplayHelper 검증 — §1.5 밴드 경계·라벨 통일·편향 2기전·구독자/유형 라벨 위임(amber/red 금지)
require "test_helper"

class ScoringDisplayHelperTest < ActionView::TestCase
  # --- performance_band_class 밴드 경계(§1.5 순차 그린 램프) ---

  test "1.5배는 중립(text-ink-muted, 배경 없음)" do
    cls = performance_band_class(1.5)
    assert_includes cls, "text-ink-muted"
    assert_includes cls, "font-normal"
    refute_includes cls, "bg-"
  end

  test "nil 배수는 중립(text-ink-muted, 배경 없음)" do
    cls = performance_band_class(nil)
    assert_includes cls, "text-ink-muted"
    refute_includes cls, "bg-"
  end

  test "2.0배는 good(bg-success-50 text-mult-good)" do
    cls = performance_band_class(2.0)
    assert_includes cls, "bg-success-50"
    assert_includes cls, "text-mult-good"
  end

  test "3.0배는 good" do
    cls = performance_band_class(3.0)
    assert_includes cls, "bg-success-50"
    assert_includes cls, "text-mult-good"
  end

  test "5.0배는 strong(bg-success-100 text-mult-strong)" do
    cls = performance_band_class(5.0)
    assert_includes cls, "bg-success-100"
    assert_includes cls, "text-mult-strong"
  end

  test "7.0배는 strong" do
    cls = performance_band_class(7.0)
    assert_includes cls, "bg-success-100"
    assert_includes cls, "text-mult-strong"
  end

  test "10.0배는 strong(경계 포함)" do
    cls = performance_band_class(10.0)
    assert_includes cls, "bg-success-100"
    assert_includes cls, "text-mult-strong"
  end

  test "12.0배는 breakout(bg-mult-breakout text-white)" do
    cls = performance_band_class(12.0)
    assert_includes cls, "bg-mult-breakout"
    assert_includes cls, "text-white"
  end

  test "밴드 클래스는 amber/red/warning/danger를 쓰지 않는다" do
    [nil, 1.5, 2.0, 3.0, 5.0, 7.0, 10.0, 12.0, 30.0].each do |m|
      cls = performance_band_class(m)
      %w[warning amber red danger].each do |forbidden|
        refute_includes cls, forbidden, "밴드 #{m}배에 금지색 #{forbidden} 사용"
      end
    end
  end

  # --- 라벨·편향 ---

  test "performance_multiple_label 는 통일 라벨" do
    assert_equal "성과 배수(채널 평소 대비)", performance_multiple_label
    refute_includes performance_multiple_label, "구독자 대비 조회수"
  end

  test "performance_bias_note 는 두 편향 기전을 명명한다" do
    note = performance_bias_note
    assert_includes note, "누적 조회수"
    assert_includes note, "기준선"
  end

  # --- video_type_label ---

  test "video_type_label 는 is_short 로 쇼츠/롱폼/미상(nil)" do
    assert_equal "쇼츠", video_type_label(Video.new(is_short: true))
    assert_equal "롱폼", video_type_label(Video.new(is_short: false))
    assert_nil video_type_label(Video.new(is_short: nil))
  end

  # --- subscriber_band_label 위임 ---

  test "subscriber_band_label 는 SubscriberBand 에 위임한다" do
    assert_equal Scoring::SubscriberBand.label(50_000), subscriber_band_label(Channel.new(subscriber_count: 50_000))
    assert_nil subscriber_band_label(Channel.new(subscriber_count: nil))
    assert_nil subscriber_band_label(nil)
  end

  # --- own_match_badge(§1.4) ---

  test "own_match_badge 는 없음/1개/2개+ 로 neutral/caution/danger" do
    assert_equal "없음", own_match_badge(nil)[:label]
    assert_equal "없음", own_match_badge(0)[:label]
    assert_includes own_match_badge(0)[:klass], "neutral"
    assert_equal "1개", own_match_badge(1)[:label]
    assert_includes own_match_badge(1)[:klass], "caution"
    assert_equal "3개", own_match_badge(3)[:label]
    assert_includes own_match_badge(3)[:klass], "danger"
  end

  # --- youtube_watch_url ---

  test "youtube_watch_url 는 id 를 인코딩해 쿼리 오염을 막는다" do
    video = Video.new(youtube_video_id: "abc&evil=1")
    url = youtube_watch_url(video)
    assert_includes url, "https://www.youtube.com/watch?v="
    assert_not_includes url, "&evil=1", "인코딩 안 되면 별도 쿼리 파라미터로 주입됨"
  end

  # --- video_sparkline_points(스냅샷 7일, AD-3 읽기만) ---

  test "스냅샷이 임계(7) 미만이면 nil(콜드스타트 자리 유지)" do
    video = build_video_with_stats([100, 200, 300]) # 3 < 7
    assert_nil video_sparkline_points(video)
  end

  test "스냅샷 7개면 정규화된 polyline points 를 낸다" do
    video = build_video_with_stats([10, 20, 30, 40, 50, 60, 70])
    pts = video_sparkline_points(video, width: 96, height: 28)
    assert_not_nil pts
    coords = pts.split(" ")
    assert_equal 7, coords.size
    assert coords.first.start_with?("0.0,"), "첫 점 x=0"
    assert coords.last.start_with?("96.0,"), "마지막 점 x=width"
  end

  test "창 안에 결측(nil) 조회수가 있으면 nil(가짜 바닥선 방지, AD-9)" do
    video = build_video_with_stats([10, 20, nil, 40, 50, 60, 70])
    assert_nil video_sparkline_points(video)
  end

  # --- evergreen_badge_status(§4.7, AD-3 읽기만) ---

  test "score 가 nil 이면 뱃지 없음(nil)" do
    video = build_video_with_stats([])
    assert_nil evergreen_badge_status(nil, video)
  end

  test "evergreen_candidate=false 면 뱃지 없음(nil)" do
    video = build_evergreen_video(candidate: false, stat_count: 20)
    assert_nil evergreen_badge_status(video.video_score, video)
  end

  test "후보이며 스냅샷<14 면 :evergreen_candidate(ghost)" do
    video = build_evergreen_video(candidate: true, stat_count: 5)
    assert_equal :evergreen_candidate, evergreen_badge_status(video.video_score, video)
  end

  test "후보이며 스냅샷 0 이면 :evergreen_candidate(AD-9)" do
    video = build_evergreen_video(candidate: true, stat_count: 0)
    assert_equal :evergreen_candidate, evergreen_badge_status(video.video_score, video)
  end

  test "후보이며 스냅샷>=14 면 :evergreen_verified(solid)" do
    video = build_evergreen_video(candidate: true, stat_count: 14)
    assert_equal :evergreen_verified, evergreen_badge_status(video.video_score, video)
  end

  private

  # evergreen_candidate 플래그와 stat_count 개의 daily_stats(유니크 날짜)를 심은 영상 생성.
  def build_evergreen_video(candidate:, stat_count:)
    channel = Channel.create!(name: "에버그린 채널", category: "직접경쟁", source: "seed", subscriber_count: 1000)
    video = channel.videos.create!(youtube_video_id: "evg_#{SecureRandom.hex(4)}", title: "에버그린 영상")
    VideoScore.create!(video: video, performance_multiple: 3.0, rank_eligible: true,
                       needs_verification: false, evergreen_candidate: candidate)
    stat_count.times { |i| video.daily_stats.create!(date: (stat_count - i).days.ago.to_date, view_count: 100 + i) }
    video
  end

  # 오래된→최신 순 view_count 배열로 daily_stats 를 심은 영상 생성(날짜 오름차순).
  def build_video_with_stats(view_counts)
    channel = Channel.create!(name: "스파크라인 채널", category: "직접경쟁", source: "seed", subscriber_count: 1000)
    video = channel.videos.create!(youtube_video_id: "spk_#{SecureRandom.hex(4)}", title: "추이 영상")
    view_counts.each_with_index do |vc, i|
      video.daily_stats.create!(date: (view_counts.size - i).days.ago.to_date, view_count: vc)
    end
    video
  end

  # --- youtube_channel_url — UC id/핸들/없음 ---

  test "youtube_channel_url 은 UC id 를 channel URL 로" do
    ch = Channel.create!(name: "채널A", category: "직접경쟁", source: "seed", youtube_channel_id: "UCabc123")
    assert_equal "https://www.youtube.com/channel/UCabc123", youtube_channel_url(ch)
  end

  test "youtube_channel_url 은 UC id 없으면 @핸들로(앞의 @ 보정)" do
    ch = Channel.create!(name: "채널B", category: "직접경쟁", source: "seed", handle: "myhandle")
    assert_equal "https://www.youtube.com/@myhandle", youtube_channel_url(ch)
  end

  test "youtube_channel_url 은 id·핸들 모두 없으면 nil(링크 미생성)" do
    ch = Channel.create!(name: "채널C", category: "직접경쟁", source: "seed")
    assert_nil youtube_channel_url(ch)
  end
end
