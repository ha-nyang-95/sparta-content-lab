# 콘텐츠 갭 헬퍼 — 기회 가중 평균·화이트리스트·세그먼트(합=원둘레·§10 색만)·라벨 매핑 검증
require "test_helper"

class ContentGapHelperTest < ActionView::TestCase
  # 버킷 키 3중 소재지(모델 CONTENT_GAP_BUCKETS·헬퍼 BUCKET_ORDER·scoring.yml content_gap_values)가
  # 어긋나면 가중 평균이 nil 곱셈으로 500 나거나 도넛에 빈 링이 생긴다 — 락스텝을 강제한다(운영자 튜닝 드리프트 방어).
  test "버킷 키 소재지 3곳이 정렬돼 있다(드리프트 방어)" do
    config_keys = Scoring::Config.fetch(:opportunity_score, :normalization)[:content_gap_values].keys.map(&:to_s)
    assert_equal VideoScore::CONTENT_GAP_BUCKETS.sort, ContentGapHelper::BUCKET_ORDER.sort, "모델 ↔ 헬퍼 버킷 불일치"
    assert_equal VideoScore::CONTENT_GAP_BUCKETS.sort, config_keys.sort, "모델 ↔ scoring.yml 버킷 불일치"
    assert_equal VideoScore::CONTENT_GAP_BUCKETS.sort, ContentGapHelper::BUCKET_LABELS.keys.sort, "모델 ↔ 라벨 불일치"
    assert_equal VideoScore::CONTENT_GAP_BUCKETS.sort, ContentGapHelper::BUCKET_STROKE.keys.sort, "모델 ↔ stroke 색 불일치"
    assert_equal VideoScore::CONTENT_GAP_BUCKETS.sort, ContentGapHelper::BUCKET_DOT.keys.sort, "모델 ↔ dot 색 불일치"
  end

  test "content_gap_opportunity_pct 전부 미제작 → 100" do
    assert_equal 100, content_gap_opportunity_pct({ "not_made" => 4 })
  end

  test "content_gap_opportunity_pct 전부 포화 → 0" do
    assert_equal 0, content_gap_opportunity_pct({ "saturated" => 4 })
  end

  test "content_gap_opportunity_pct 미제작1+포화1 → 50" do
    assert_equal 50, content_gap_opportunity_pct({ "not_made" => 1, "saturated" => 1 })
  end

  test "content_gap_opportunity_pct 유사1개 1건 → 66" do
    assert_equal 66, content_gap_opportunity_pct({ "one" => 1 })
  end

  test "content_gap_opportunity_pct 빈 분포 → nil" do
    assert_nil content_gap_opportunity_pct({})
  end

  test "permitted_content_gap_bucket 유효값 통과" do
    assert_equal "one", permitted_content_gap_bucket({ bucket: "one" })
  end

  test "permitted_content_gap_bucket 잘못된 값 → not_made" do
    assert_equal "not_made", permitted_content_gap_bucket({ bucket: "xxx" })
  end

  test "permitted_content_gap_bucket 부재 → not_made" do
    assert_equal "not_made", permitted_content_gap_bucket({})
  end

  test "content_gap_segments fraction 합 1.0·dash 합 ≈ 원둘레" do
    dist = { "not_made" => 2, "one" => 1, "few" => 1 }
    circ = 2 * Math::PI * 52
    segs = content_gap_segments(dist, circumference: circ)
    assert_in_delta 1.0, segs.sum { |s| s[:fraction] }, 0.001
    assert_in_delta circ, segs.sum { |s| s[:dash] }, 0.001
  end

  test "content_gap_segments 는 §10 stroke 토큰만(원시 색 부재)" do
    segs = content_gap_segments({ "not_made" => 1, "one" => 1, "few" => 1, "saturated" => 1 }, circumference: 100)
    classes = segs.map { |s| s[:stroke_class] }.join(" ")
    assert_no_match(/(stroke|fill)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]/, classes)
  end

  test "content_gap_bucket_label 4구간 매핑" do
    assert_equal "미제작", content_gap_bucket_label("not_made")
    assert_equal "유사 1개", content_gap_bucket_label("one")
    assert_equal "유사 2개+", content_gap_bucket_label("few")
    assert_equal "포화", content_gap_bucket_label("saturated")
  end
end
