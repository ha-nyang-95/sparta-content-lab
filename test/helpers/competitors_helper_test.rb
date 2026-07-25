# CompetitorsHelper — 구독자 증감 3상태(콜드/측정한계/증가·감소·nil 방어)·아바타 이니셜/파스텔(§10 토큰 한정)
require "test_helper"

class CompetitorsHelperTest < ActionView::TestCase
  def channel_with_stats(counts)
    channel = Channel.create!(name: "테스트 채널", category: "직접경쟁", source: "seed", is_own: false)
    counts.each_with_index do |count, i|
      channel.daily_stats.create!(date: Date.new(2026, 1, 1) + i, subscriber_count: count)
    end
    channel
  end

  test "스냅샷 7 미만이면 collecting" do
    state = subscriber_delta_state(channel_with_stats([100, 100, 100, 100, 100, 100]))
    assert_equal :collecting, state[:state]
    assert_equal 6, state[:days]
  end

  test "|증감%| 가 임계 미만이면 immaterial" do
    # 100000 → 100200 = +0.2% < min_material_pct(0.5)
    state = subscriber_delta_state(channel_with_stats([100_000, 100_020, 100_040, 100_060, 100_080, 100_100, 100_200]))
    assert_equal :immaterial, state[:state]
  end

  test "증가가 임계 이상이면 material :up" do
    # 100000 → 106000 = +6%
    state = subscriber_delta_state(channel_with_stats([100_000, 101_000, 102_000, 103_000, 104_000, 105_000, 106_000]))
    assert_equal :material, state[:state]
    assert_equal :up, state[:direction]
    assert_in_delta 6.0, state[:pct], 0.001
  end

  test "감소가 임계 이상이면 material :down" do
    # 100000 → 94000 = -6%
    state = subscriber_delta_state(channel_with_stats([100_000, 99_000, 98_000, 97_000, 96_000, 95_000, 94_000]))
    assert_equal :material, state[:state]
    assert_equal :down, state[:direction]
  end

  test "earliest 가 nil 이면 collecting(0 나눗셈 방어)" do
    state = subscriber_delta_state(channel_with_stats([nil, 100_000, 100_000, 100_000, 100_000, 100_000, 106_000]))
    assert_equal :collecting, state[:state]
  end

  test "latest 가 nil 이면 collecting(가짜 −100% 붕괴 방어, AD-9)" do
    # 마지막 스냅샷 구독자 숨김 → 0 강압하면 −100% 로 오표시되던 버그.
    state = subscriber_delta_state(channel_with_stats([100_000, 100_000, 100_000, 100_000, 100_000, 100_000, nil]))
    assert_equal :collecting, state[:state]
  end

  test "subscriber_delta_bar_width 는 0..100 으로 클램프한다" do
    assert_equal 100, subscriber_delta_bar_width(20.0) # bar_full_pct 5.0 초과 → 100
    assert_equal 60, subscriber_delta_bar_width(3.0)   # 3/5*100
    assert_equal 100, subscriber_delta_bar_width(-20.0)
  end

  test "avatar_initial 은 첫 글자 대문자, 빈 이름은 '?'" do
    assert_equal "A", avatar_initial("abc")
    assert_equal "한", avatar_initial("한국어")
    assert_equal "?", avatar_initial("")
    assert_equal "?", avatar_initial(nil)
    assert_equal "?", avatar_initial("   ")
  end

  test "avatar_style 은 결정적이고 §10 토큰만 쓴다(원시 색 없음)" do
    a = avatar_style("韓国語の森")
    assert_equal a, avatar_style("韓国語の森"), "같은 이름 → 같은 스타일(결정적)"
    assert_includes CompetitorsHelper::AVATAR_PALETTE, a
    assert_no_match(/(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-\d/, a)
  end

  test "format_subscriber_count — YouTube 식 축약(만·억)" do
    assert_equal "588만", format_subscriber_count(5_880_000)
    assert_equal "173만", format_subscriber_count(1_730_000)
    assert_equal "21만", format_subscriber_count(210_000)
    assert_equal "5.2만", format_subscriber_count(52_200)
    assert_equal "1만", format_subscriber_count(10_200)
    assert_equal "9,999", format_subscriber_count(9_999)
    assert_equal "1억", format_subscriber_count(100_000_000)
    assert_equal "미상", format_subscriber_count(nil)
  end
end
