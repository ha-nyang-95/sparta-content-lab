# 공유 partial 렌더 검증 — 배수 셀 밴드·nil, 정직성 5+1상태 토큰, 영상 행 다국어 방어·"구독자 대비 조회수" 부재
require "test_helper"

class SharedComponentsTest < ActionView::TestCase
  # --- _performance_cell ---

  test "performance_cell 3.0배는 good 밴드·편향 주석을 담고 금지 라벨이 없다" do
    render partial: "shared/performance_cell", locals: { multiple: 3.0, view_count: 12_345 }
    assert_includes rendered, "bg-success-50"
    assert_includes rendered, "text-mult-good"
    assert_includes rendered, "3.0×"
    assert_includes rendered, "누적 조회수"
    assert_includes rendered, "12,345"
    refute_includes rendered, "구독자 대비 조회수"
  end

  test "performance_cell nil 배수는 —, 밴드 배경 없음" do
    render partial: "shared/performance_cell", locals: { multiple: nil, view_count: nil }
    assert_includes rendered, "—"
    refute_includes rendered, "bg-success-50"
    refute_includes rendered, "bg-success-100"
    refute_includes rendered, "bg-mult-breakout"
  end

  test "performance_cell needs_verification 는 검증 요망 플래그를 겹친다" do
    render partial: "shared/performance_cell", locals: { multiple: 30.0, view_count: 999, needs_verification: true }
    assert_includes rendered, "검증 요망"
    assert_includes rendered, "text-warning-600"
  end

  # --- _honesty_status 5+1상태 ---

  test "honesty_status collecting 은 dashed 보더로 자리 유지" do
    render partial: "shared/honesty_status", locals: { status: :collecting }
    assert_includes rendered, "border-dashed"
    assert_includes rendered, "데이터 수집 중"
  end

  test "honesty_status measurement_limit 은 neutral 칩" do
    render partial: "shared/honesty_status", locals: { status: :measurement_limit }
    assert_includes rendered, "bg-badge-neutralBg"
    assert_includes rendered, "측정한계"
  end

  test "honesty_status evergreen_candidate 는 ghost 뱃지" do
    render partial: "shared/honesty_status", locals: { status: :evergreen_candidate }
    assert_includes rendered, "border-success-100"
    assert_includes rendered, "text-success-700"
    assert_includes rendered, "에버그린 후보"
  end

  test "honesty_status evergreen_verified 는 solid" do
    render partial: "shared/honesty_status", locals: { status: :evergreen_verified }
    assert_includes rendered, "bg-success-600"
    assert_includes rendered, "text-white"
  end

  test "honesty_status needs_verification 은 amber 플래그" do
    render partial: "shared/honesty_status", locals: { status: :needs_verification }
    assert_includes rendered, "text-warning-600"
    assert_includes rendered, "border-warning-500"
    assert_includes rendered, "검증 요망"
  end

  test "honesty_status low_confidence 는 저신뢰 텍스트 + 툴팁" do
    render partial: "shared/honesty_status", locals: { status: :low_confidence }
    assert_includes rendered, "저신뢰"
    assert_includes rendered, "text-warning-600"
    assert_includes rendered, "신뢰도 낮음"
  end

  test "honesty_status 알 수 없는 status 는 무표시(안전)" do
    render partial: "shared/honesty_status", locals: { status: :unknown_state }
    assert_equal "", rendered.strip
  end

  # --- _video_row ---

  def build_scored_video(title:, is_short: false, own_match_count: 3, multiple: 4.0)
    channel = Channel.create!(name: "테스트 채널", category: "직접경쟁", source: "seed", subscriber_count: 50_000)
    video = channel.videos.create!(
      youtube_video_id: "vr_#{SecureRandom.hex(4)}",
      title: title,
      view_count: 54_321,
      is_short: is_short,
      published_at: Time.utc(2026, 5, 1),
      thumbnail: "https://example.com/t.jpg"
    )
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: own_match_count, needs_verification: false, rank_eligible: true)
    video
  end

  test "video_row 는 다국어 방어·유형·유사영상을 담고 금지 라벨이 없다" do
    video = build_scored_video(title: "일본어 강좌", is_short: false, own_match_count: 2)
    render partial: "shared/video_row", locals: { video: video }
    assert_includes rendered, "break-keep"
    assert_includes rendered, "line-clamp"
    assert_includes rendered, "tabular-nums"
    assert_includes rendered, "min-w-0"
    assert_includes rendered, "일본어 강좌"
    assert_includes rendered, "2개"
    assert_includes rendered, "롱폼"
    assert_includes rendered, "1만~10만"
    refute_includes rendered, "구독자 대비 조회수"
  end

  test "video_row own_match_count 0 은 없음으로" do
    video = build_scored_video(title: "매치 없음 영상", own_match_count: 0)
    render partial: "shared/video_row", locals: { video: video }
    assert_includes rendered, "없음"
  end

  test "video_row 한일 혼재 긴 제목은 line-clamp + title 전체 툴팁" do
    long = "일본인을 위한 韓国語 講座 완전정복 가이드"
    video = build_scored_video(title: long)
    render partial: "shared/video_row", locals: { video: video }
    assert_includes rendered, "line-clamp-2"
    assert_includes rendered, "title=\"#{long}\""
    assert_includes rendered, long
  end
  test "성과 셀 — 반올림 표시와 밴드가 같은 값에서 나온다(1.96→2.0× good, 색·숫자 일치)" do
    render partial: "shared/performance_cell", locals: { multiple: 1.96, view_count: 1000 }
    assert_includes rendered, "2.0×", "표시는 반올림값"
    assert_includes rendered, "text-mult-good", "밴드도 반올림값(2.0) 기준이라 good"
    assert_not_includes rendered, "text-ink-muted font-normal", "1.96 을 neutral 로 표시하지 않는다(불일치 방지)"
  end

  test "성과 셀 — 4.96→5.0× strong(반올림 일치)" do
    render partial: "shared/performance_cell", locals: { multiple: 4.96, view_count: 1000 }
    assert_includes rendered, "5.0×"
    assert_includes rendered, "text-mult-strong"
  end

end
