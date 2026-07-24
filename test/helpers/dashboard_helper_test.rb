# 대시보드 헬퍼 — 7.1 검색·필터·정렬 화이트리스트/폴백·검색어 정규화·옵션 형태 검증
require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  test "permitted_sort 화이트리스트 통과·오입력 폴백" do
    assert_equal "views", permitted_sort(sort: "views")
    assert_equal "recent", permitted_sort(sort: "recent")
    assert_equal "multiple", permitted_sort(sort: "multiple")
    assert_equal "multiple", permitted_sort(sort: "xxx")
    assert_equal "multiple", permitted_sort({})
  end

  test "permitted_min_multiple 화이트리스트·프리셋 외 폴백" do
    assert_equal "5", permitted_min_multiple(min_multiple: "5")
    assert_equal "all", permitted_min_multiple(min_multiple: "all")
    assert_equal "all", permitted_min_multiple(min_multiple: "99")
    assert_equal "all", permitted_min_multiple({})
  end

  test "permitted_band 화이트리스트·범위 외 폴백" do
    assert_equal "2", permitted_band(band: "2")
    assert_equal "all", permitted_band(band: "all")
    assert_equal "all", permitted_band(band: "9")
    assert_equal "all", permitted_band({})
  end

  test "search_query 는 strip + 100자 상한 + nil→''" do
    assert_equal "조사", search_query(q: "  조사  ")
    assert_equal "", search_query(q: "   ")
    assert_equal "", search_query(q: nil)
    assert_equal "", search_query({})
    long = "a" * 250
    assert_equal 100, search_query(q: long).length
  end

  test "multiple_options 는 all + 프리셋(2..25)" do
    keys = multiple_options.map(&:first)
    assert_equal "all", keys.first
    assert_includes keys, "2"
    assert_includes keys, "5"
    assert_includes keys, "25"
    assert_equal Scoring::Config.fetch(:performance, :multiple_presets).map(&:to_s), keys[1..]
  end

  test "sort_options 형태 — [key, label] 쌍" do
    assert_equal %w[multiple views recent], sort_options.map(&:first)
    assert(sort_options.all? { |k, l| k.is_a?(String) && l.is_a?(String) })
  end

  test "band_options 형태 — all + 0..3" do
    assert_equal %w[all 0 1 2 3], band_options.map(&:first)
    assert(band_options.all? { |k, l| k.is_a?(String) && l.is_a?(String) })
  end

  # 드리프트 방어 — band_options 티어 수가 scoring.yml subscriber_bands 임계 수와 어긋나면
  # 컨트롤러가 t[존재하지 않는 인덱스] = nil 로 아무것도 매치 못하는 팬텀 티어가 생긴다.
  test "band_options 티어 수가 subscriber_bands 임계 수와 일치한다(팬텀 티어 방어)" do
    thresholds = Scoring::Config.fetch(:subscriber_bands)
    tiers = band_options.map(&:first) - ["all"]
    assert_equal thresholds.size + 1, tiers.size, "밴드 티어 수 = 임계 수 + 1"
  end
end
