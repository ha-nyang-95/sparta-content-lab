# Scoring::CalculateOpportunityScore — 4입력 정규화(성과·공통성·갭·최신성)·가중합 ×100·경계·nil 방어·구조 불변·물질화·결정성 검증
require "test_helper"

class Scoring::CalculateOpportunityScoreTest < ActiveSupport::TestCase
  # 튜닝값은 설정 파일 경로로 읽어 하드코딩 회귀를 테스트가 잡게 한다(AD-4).
  WEIGHTS = Scoring::Config.fetch(:opportunity_score, :weights)
  NORM    = Scoring::Config.fetch(:opportunity_score, :normalization)

  setup do
    @own = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @competitor = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @seq = 0
  end

  # 멤버 스펙(해시 배열)으로 클러스터 하나를 구성한다 — channel/multiple/bucket/age_days(또는 published_at) 지정.
  # multiple·bucket 중 하나라도 있으면 VideoScore 를 만든다(둘 다 없으면 점수 없는 멤버).
  def make_cluster(members)
    cluster = TopicCluster.create!(size: members.size)
    members.each do |m|
      @seq += 1
      pub =
        if m.key?(:published_at)
          m[:published_at]
        elsif m[:age_days]
          Time.zone.today - m[:age_days].days
        end
      video = (m[:channel] || @competitor).videos.create!(
        youtube_video_id: "vid_#{@seq}",
        title: "영상 #{@seq}",
        is_short: false,
        published_at: pub,
        topic_cluster: cluster
      )
      if m.key?(:multiple) || m.key?(:bucket)
        VideoScore.create!(video: video, performance_multiple: m[:multiple], content_gap_bucket: m[:bucket])
      end
    end
    cluster
  end

  # 4 정규화 값에서 기대 종합 점수를 config 가중치로 재계산(하드코딩 없이).
  def expected_score(perf:, commonality:, gap:, recency:)
    (WEIGHTS[:performance_signal] * perf +
     WEIGHTS[:competitor_commonality] * commonality +
     WEIGHTS[:content_gap] * gap +
     WEIGHTS[:recency] * recency) * 100.0
  end

  test "성과 정규화 — 최대 배수 divisor×0.5 → perf_norm 0.5(종합 점수에 반영)" do
    multiple = NORM[:performance_divisor] * 0.5 # divisor 10 → 5
    cluster = make_cluster([{ channel: @competitor, multiple: multiple }])
    Scoring::CalculateOpportunityScore.new.call
    # 경쟁 멤버 1 → commonality 1/cap, 갭·최신성 없음 → 0.
    expected = expected_score(perf: 0.5, commonality: 1.0 / NORM[:commonality_cap], gap: 0.0, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "성과 상한 — 최대 배수 divisor×2 → perf_norm 1.0(min 상한)" do
    multiple = NORM[:performance_divisor] * 2 # 20
    cluster = make_cluster([{ channel: @competitor, multiple: multiple }])
    Scoring::CalculateOpportunityScore.new.call
    expected = expected_score(perf: 1.0, commonality: 1.0 / NORM[:commonality_cap], gap: 0.0, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "갭 매핑 not_made — gap_norm = content_gap_values[not_made]" do
    cluster = make_cluster([{ channel: @competitor, bucket: "not_made" }])
    Scoring::CalculateOpportunityScore.new.call
    gap = NORM[:content_gap_values][:not_made] # 1.0
    expected = expected_score(perf: 0.0, commonality: 1.0 / NORM[:commonality_cap], gap: gap, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "갭 매핑 saturated — gap_norm = content_gap_values[saturated] (0.0)" do
    cluster = make_cluster([{ channel: @competitor, bucket: "saturated" }])
    Scoring::CalculateOpportunityScore.new.call
    gap = NORM[:content_gap_values][:saturated] # 0.0
    expected = expected_score(perf: 0.0, commonality: 1.0 / NORM[:commonality_cap], gap: gap, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "최신성 감쇠 — 경과일 decay×0.5 → recency 0.5" do
    age = NORM[:recency_full_decay_days] / 2 # 90/2 = 45
    cluster = make_cluster([{ channel: @competitor, age_days: age }])
    Scoring::CalculateOpportunityScore.new.call
    recency = 1.0 - (age.to_f / NORM[:recency_full_decay_days]) # 0.5
    expected = expected_score(perf: 0.0, commonality: 1.0 / NORM[:commonality_cap], gap: 0.0, recency: recency)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "최신성 하한 — 경과일 > decay → recency 0.0(max 0)" do
    age = NORM[:recency_full_decay_days] + 10 # 100 > 90
    cluster = make_cluster([{ channel: @competitor, age_days: age }])
    Scoring::CalculateOpportunityScore.new.call
    expected = expected_score(perf: 0.0, commonality: 1.0 / NORM[:commonality_cap], gap: 0.0, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "공통성 상한 — 경쟁 채널 수 > cap → commonality 1.0(min 상한)" do
    over_cap = NORM[:commonality_cap] + 1 # 6
    members = Array.new(over_cap) do
      ch = Channel.create!(name: "경쟁 #{SecureRandom.hex(3)}", category: "직접경쟁", source: "auto", is_own: false)
      { channel: ch }
    end
    cluster = make_cluster(members)
    Scoring::CalculateOpportunityScore.new.call
    expected = expected_score(perf: 0.0, commonality: 1.0, gap: 0.0, recency: 0.0)
    assert_in_delta expected, cluster.reload.opportunity_score, 1e-6
  end

  test "구조 불변(KEY) — 경쟁 성과 만점이어도 종합 점수는 100 미만(4입력 구조)" do
    # 경쟁 멤버 1, 성과 만점(perf 1.0), 갭·최신성 없음(bucket 없음·published nil) → 성과가 점수를 만점으로 못 만든다.
    multiple = NORM[:performance_divisor] # 10 → perf_norm 1.0
    cluster = make_cluster([{ channel: @competitor, multiple: multiple }])
    Scoring::CalculateOpportunityScore.new.call
    expected = expected_score(perf: 1.0, commonality: 1.0 / NORM[:commonality_cap], gap: 0.0, recency: 0.0)
    score = cluster.reload.opportunity_score
    assert_in_delta expected, score, 1e-6
    assert score < 100.0, "성과 단독은 종합 점수를 만점으로 만들지 않는다(4입력 구조 불변)"
  end

  test "자사 전용 클러스터(경쟁 멤버 0)는 기회 점수 0 — '다음 주 제작할 주제'가 아니다" do
    cluster = make_cluster([
      { channel: @own, multiple: NORM[:performance_divisor], bucket: "not_made", age_days: 3 },
      { channel: @own, multiple: 8.0, age_days: 1 }
    ])
    Scoring::CalculateOpportunityScore.new.call
    assert_in_delta 0.0, cluster.reload.opportunity_score, 1e-6,
      "자사만 있는 주제는 이미 만든 것이라 기회 0(경쟁 신호 없음)"
  end

  test "미래 발행(음수 경과일)·전 입력 만점이어도 [0,100] clamp 로 100 초과 금지" do
    # 경쟁 cap개 채널, 각 성과 상한·not_made, 발행일을 미래로(음수 경과일 → 미clamp면 recency>1).
    members = Array.new(NORM[:commonality_cap]) do
      ch = Channel.create!(name: "경쟁 #{SecureRandom.hex(3)}", category: "직접경쟁", source: "auto", is_own: false)
      { channel: ch, multiple: NORM[:performance_divisor] * 2, bucket: "not_made",
        published_at: Time.zone.today + NORM[:recency_full_decay_days].days }
    end
    cluster = make_cluster(members)
    Scoring::CalculateOpportunityScore.new.call
    score = cluster.reload.opportunity_score
    assert score <= 100.0, "미래 발행이어도 100 초과 금지(clamp)"
    assert_in_delta 100.0, score, 1e-6, "전 입력 정규화 상한이면 정확히 100(recency 상한 clamp 확인)"
  end

  test "정상 점수 — 4입력 모두 있음 → 정규화·가중합·×100 종합" do
    # 경쟁 채널 2곳 멤버(공통성 2/cap), 최대 배수 5(perf 0.5), 갭 not_made(1.0), 최근 경과일 45(recency 0.5).
    ch2 = Channel.create!(name: "경쟁2", category: "직접경쟁", source: "auto", is_own: false)
    cluster = make_cluster([
      { channel: @competitor, multiple: 5.0, bucket: "not_made", age_days: 45 },
      { channel: ch2,         multiple: 3.0, bucket: "saturated", age_days: 60 }
    ])
    Scoring::CalculateOpportunityScore.new.call
    perf = [5.0 / NORM[:performance_divisor], 1.0].min
    commonality = [2.0 / NORM[:commonality_cap], 1.0].min
    gap = (NORM[:content_gap_values][:not_made] + NORM[:content_gap_values][:saturated]) / 2.0
    recency = [1.0 - (45.0 / NORM[:recency_full_decay_days]), 0.0].max # 최소 경과일 45
    expected = expected_score(perf: perf, commonality: commonality, gap: gap, recency: recency)
    score = cluster.reload.opportunity_score
    assert_in_delta expected, score, 1e-6
    assert score >= 0.0 && score <= 100.0
  end

  test "nil 방어 — 멤버에 VideoScore·published_at 없음 → 모든 입력 0·예외 없음·점수 0" do
    cluster = make_cluster([{ channel: @own, published_at: nil }]) # 자사·점수 없음·발행일 없음
    assert_nothing_raised { Scoring::CalculateOpportunityScore.new.call }
    assert_in_delta 0.0, cluster.reload.opportunity_score, 1e-6
  end

  test "물질화 — 호출 후 opportunity_score 는 [0,100] 범위 Float" do
    cluster = make_cluster([{ channel: @competitor, multiple: 5.0, bucket: "one", age_days: 30 }])
    Scoring::CalculateOpportunityScore.new.call
    score = cluster.reload.opportunity_score
    assert_kind_of Float, score
    assert score >= 0.0 && score <= 100.0
  end

  test "결정적·idempotent — 두 번 실행해도 같은 점수" do
    cluster = make_cluster([{ channel: @competitor, multiple: 7.0, bucket: "few", age_days: 20 }])
    Scoring::CalculateOpportunityScore.new.call
    first = cluster.reload.opportunity_score
    Scoring::CalculateOpportunityScore.new.call
    assert_in_delta first, cluster.reload.opportunity_score, 1e-9
  end
end
