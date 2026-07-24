# Scoring::CalculatePerformance — 성과 배수·조회수 하한 상대식·극단 배수 플래그·퇴화 기준선 방어·유형 정합·idempotent·축 분리 검증
require "test_helper"

class Scoring::CalculatePerformanceTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "성과 배수 채널", category: "직접경쟁", source: "seed")
    @seq = 0
  end

  # 튜닝값은 설정 파일 경로로 읽어 하드코딩 회귀를 테스트가 잡게 한다(AD-4).
  FIXED   = Scoring::Config.fetch(:performance, :view_floor_fixed)   # 300
  K       = Scoring::Config.fetch(:performance, :view_floor_k)       # 0.1
  EXTREME = Scoring::Config.fetch(:performance, :extreme_multiple)   # 25

  def make_video(view_count:, is_short:)
    @seq += 1
    @channel.videos.create!(
      youtube_video_id: "vid_#{@seq}",
      title: "영상 #{@seq}",
      view_count: view_count,
      is_short: is_short
    )
  end

  # 유형별 기준선을 직접 생성(정확한 median 제어). short/long 중 준 것만 만든다.
  def set_baseline(video_type, median)
    Baseline.create!(channel: @channel, video_type: video_type, median_view_count: median, sample_size: 10, low_confidence: false)
  end

  def score_for(video)
    VideoScore.find_by(video: video)
  end

  test "정상 배수 — view 1000 / 롱폼 기준선 200 = 5.0, rank_eligible true" do
    set_baseline("long", 200.0)
    v = make_video(view_count: 1000, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_in_delta 5.0, s.performance_multiple, 1e-9
    assert s.rank_eligible          # 1000 >= max(300, 0.1*200=20) = 300
    assert_not s.needs_verification # 5 <= 25
  end

  test "하한 상대식 — 기준선 5000 → floor=max(300,500)=500; view 400 → rank_eligible false" do
    set_baseline("long", 5000.0)
    v = make_video(view_count: 400, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_in_delta 0.08, s.performance_multiple, 1e-9 # 400/5000
    assert_not s.rank_eligible # 400 < 500 (상대식 k×기준선이 지배)
  end

  test "하한 고정 우위 — 기준선 100 → floor=max(300,10)=300; view 250 → rank_eligible false" do
    set_baseline("long", 100.0)
    v = make_video(view_count: 250, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_in_delta 2.5, s.performance_multiple, 1e-9
    assert_not s.rank_eligible # 250 < 300 (고정값이 지배)
  end

  test "극단 배수 — view 3000 / 기준선 100 = 30배 → needs_verification true, rank_eligible true" do
    set_baseline("long", 100.0)
    v = make_video(view_count: 3000, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_in_delta 30.0, s.performance_multiple, 1e-9
    assert s.needs_verification # 30 > 25
    assert s.rank_eligible      # 극단이어도 순위 제외 아님(독립 축), 3000 >= 300
  end

  test "nil 기준선 median(표본0) — multiple nil, rank_eligible false, 예외 없음" do
    set_baseline("long", nil) # sample-0 기준선
    v = make_video(view_count: 1000, is_short: false)
    assert_nothing_raised { Scoring::CalculatePerformance.new(@channel).call }

    s = score_for(v)
    assert_nil s.performance_multiple
    assert_not s.rank_eligible
    assert_not s.needs_verification
  end

  test "0 기준선 median(0.0 전량 0뷰) — multiple nil, rank_eligible false, ZeroDivision/Infinity 없음" do
    set_baseline("long", 0.0)
    v = make_video(view_count: 1000, is_short: false)
    assert_nothing_raised { Scoring::CalculatePerformance.new(@channel).call }

    s = score_for(v)
    assert_nil s.performance_multiple
    assert_not (s.performance_multiple.respond_to?(:infinite?) && s.performance_multiple&.infinite?)
    assert_not s.rank_eligible
  end

  test "기준선 부재 — 해당 유형 Baseline 행 없음 → multiple nil, rank_eligible false" do
    # long 기준선만 만들고 short 영상을 준다 → short 기준선 부재.
    set_baseline("long", 200.0)
    v = make_video(view_count: 1000, is_short: true)
    assert_nothing_raised { Scoring::CalculatePerformance.new(@channel).call }

    s = score_for(v)
    assert_nil s.performance_multiple
    assert_not s.rank_eligible
  end

  test "nil view_count(회원 전용) — multiple nil, rank_eligible false" do
    set_baseline("long", 200.0)
    v = make_video(view_count: nil, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_not_nil s, "회원 전용도 유형 확정이면 방어 행은 물질화된다"
    assert_nil s.performance_multiple
    assert_not s.rank_eligible
  end

  test "is_short nil(미분류) — VideoScore 행 미물질화" do
    set_baseline("long", 200.0)
    set_baseline("short", 200.0)
    v = make_video(view_count: 1000, is_short: nil)
    Scoring::CalculatePerformance.new(@channel).call

    assert_nil score_for(v), "유형 미확정 영상은 점수 행이 생기지 않는다"
    assert_equal 0, VideoScore.count
  end

  test "유형 정합 — 쇼츠는 short 기준선, 롱폼은 long 기준선(다른 분모)" do
    set_baseline("short", 1000.0)
    set_baseline("long", 100.0)
    short_v = make_video(view_count: 2000, is_short: true)
    long_v  = make_video(view_count: 2000, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    assert_in_delta 2.0,  score_for(short_v).performance_multiple, 1e-9 # 2000/1000
    assert_in_delta 20.0, score_for(long_v).performance_multiple, 1e-9  # 2000/100
  end

  test "재계산 idempotent — 두 번 실행해도 같은 행 갱신, 중복 없음" do
    set_baseline("long", 200.0)
    v = make_video(view_count: 1000, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call
    first_id = score_for(v).id
    assert_in_delta 5.0, score_for(v).performance_multiple, 1e-9

    # 조회수 갱신 후 재실행 → 같은 행이 갱신되고 행 수 유지.
    v.update!(view_count: 400)
    Scoring::CalculatePerformance.new(@channel).call

    assert_equal 1, VideoScore.count
    assert_equal first_id, score_for(v).id
    assert_in_delta 2.0, score_for(v).performance_multiple, 1e-9
  end

  test "자사 실측(200~4,100) 픽스처 — 여러 시나리오 결합" do
    set_baseline("long", 890.0)   # 3.1 실측 롱폼 중앙값
    set_baseline("short", 1850.0) # 3.1 실측 쇼츠 중앙값

    normal   = make_video(view_count: 4100, is_short: false) # 4100/890 ≈ 4.6배, 적격
    low_view = make_video(view_count: 200,  is_short: false)  # 200 < floor(300), 부적격
    member   = make_video(view_count: nil,  is_short: false)  # 회원 전용, 방어
    short_hit = make_video(view_count: 3900, is_short: true)  # 3900/1850 ≈ 2.1배, 적격

    Scoring::CalculatePerformance.new(@channel).call

    assert_in_delta 4100 / 890.0, score_for(normal).performance_multiple, 1e-9
    assert score_for(normal).rank_eligible

    assert_in_delta 200 / 890.0, score_for(low_view).performance_multiple, 1e-9
    assert_not score_for(low_view).rank_eligible # 200 < max(300, 89) = 300

    assert_nil score_for(member).performance_multiple
    assert_not score_for(member).rank_eligible

    assert_in_delta 3900 / 1850.0, score_for(short_hit).performance_multiple, 1e-9
    assert score_for(short_hit).rank_eligible # 3900 >= max(300, 185) = 300
  end

  # --- 경계값 (하한·극단) ---

  test "하한 경계 — view_count 가 floor 와 정확히 같으면 rank_eligible true(미만만 제외)" do
    set_baseline("long", 100.0) # floor = max(300, 10) = 300
    v = make_video(view_count: 300, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert s.rank_eligible, "floor 와 같으면(>=) 적격 — '미만'만 제외"
    assert_in_delta 3.0, s.performance_multiple, 1e-9
  end

  test "극단 경계 — 성과 배수가 extreme 와 정확히 같으면 needs_verification false(초과만 플래그)" do
    set_baseline("long", 100.0)
    v = make_video(view_count: 100 * EXTREME, is_short: false) # 정확히 25.0배
    Scoring::CalculatePerformance.new(@channel).call

    s = score_for(v)
    assert_in_delta EXTREME.to_f, s.performance_multiple, 1e-9
    assert_not s.needs_verification, "정확히 임계면 플래그 없음(초과만)"
    assert s.rank_eligible
  end

  # --- 축 분리 (성과 vs 모멘텀) ---

  test "축 분리 — VideoScore 스키마에 종합/합산 컬럼이 존재하지 않는다" do
    forbidden = %w[vpd momentum composite combined total_score overall_score]
    assert_empty (VideoScore.column_names & forbidden),
      "성과와 모멘텀을 하나로 합친 컬럼이 있으면 안 된다: #{(VideoScore.column_names & forbidden).inspect}"
  end

  test "축 분리 — performance_multiple 은 view_count ÷ 기준선의 순수 함수(모멘텀 항 없음)" do
    set_baseline("long", 400.0)
    v = make_video(view_count: 1200, is_short: false)
    Scoring::CalculatePerformance.new(@channel).call

    # 정확히 view_count / median. VPD·모멘텀 가산 항이 섞이지 않았음을 못박는다.
    assert_equal 1200.0 / 400.0, score_for(v).performance_multiple
  end
end
