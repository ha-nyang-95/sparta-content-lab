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
end
