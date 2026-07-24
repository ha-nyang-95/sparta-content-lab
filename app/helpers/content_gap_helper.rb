# 콘텐츠 갭 4구간 버킷의 표시 변환 — 도넛 세그먼트·기회 가중 평균·라벨·화이트리스트(읽기 전용 표시 변환, AD-3)
module ContentGapHelper
  BUCKET_ORDER = %w[not_made one few saturated].freeze

  BUCKET_LABELS = {
    "not_made" => "미제작",
    "one" => "유사 1개",
    "few" => "유사 2개+",
    "saturated" => "포화"
  }.freeze

  # §4.6 진→연 primary 램프 + neutral 1개(border #E5E7EB). 원시 색 금지(§10 토큰만).
  BUCKET_STROKE = {
    "not_made" => "stroke-primary-600",
    "one" => "stroke-primary-500",
    "few" => "stroke-primary-100",
    "saturated" => "stroke-border"
  }.freeze

  # 범례 dot용 — BUCKET_STROKE 와 동일 색을 bg 로.
  BUCKET_DOT = {
    "not_made" => "bg-primary-600",
    "one" => "bg-primary-500",
    "few" => "bg-primary-100",
    "saturated" => "bg-border"
  }.freeze

  def content_gap_bucket_label(key)
    BUCKET_LABELS[key] || key
  end

  # 도넛 중앙 "콘텐츠 기회" % = 버킷 기회 가중 평균 ×100(반올림). 분류 0이면 nil(콜드).
  def content_gap_opportunity_pct(distribution)
    values = Scoring::Config.fetch(:opportunity_score, :normalization)[:content_gap_values]
    total = distribution.values.sum
    return nil if total.zero?

    (distribution.sum { |bucket, count| count * values[bucket.to_sym] } / total.to_f * 100).round
  end

  # BUCKET_ORDER 순 SVG 세그먼트 — 각 버킷 {dash·gap·누적 offset·색·라벨·건수}.
  # total>0 이면 arc 합 = 원둘레(-90° 회전으로 12시 시작, offset=-누적길이로 세그먼트 연결).
  def content_gap_segments(distribution, circumference:)
    total = distribution.values.sum
    accumulated = 0.0

    BUCKET_ORDER.map do |key|
      count = distribution.fetch(key, 0)
      fraction = total.zero? ? 0.0 : count / total.to_f
      dash = fraction * circumference
      segment = {
        key: key,
        label: content_gap_bucket_label(key),
        count: count,
        fraction: fraction,
        stroke_class: BUCKET_STROKE[key],
        dash: dash,
        gap: circumference - dash,
        offset: -accumulated
      }
      accumulated += dash
      segment
    end
  end

  # 구간 필터 화이트리스트 — CONTENT_GAP_BUCKETS 만 허용, 기본 not_made(최대 기회).
  def permitted_content_gap_bucket(params)
    VideoScore::CONTENT_GAP_BUCKETS.include?(params[:bucket]) ? params[:bucket] : "not_made"
  end
end
