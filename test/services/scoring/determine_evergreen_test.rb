# Scoring::DetermineEvergreen — 나이 AND 배수 동시 충족·한쪽만 false·배수>1 아님·경계 180·nil 방어·Tokyo 경계·재계산 보존 검증
require "test_helper"

class Scoring::DetermineEvergreenTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "에버그린 채널", category: "직접경쟁", source: "seed")
    @seq = 0
  end

  # 튜닝값은 설정 파일 경로로 읽어 하드코딩 회귀를 테스트가 잡게 한다(AD-4).
  MIN_AGE      = Scoring::Config.fetch(:evergreen, :min_age_days)  # 180
  MIN_MULTIPLE = Scoring::Config.fetch(:evergreen, :min_multiple)  # 2

  # 발행일·배수를 직접 제어해 판정 로직만 격리 검증 — VideoScore 를 직접 만든다.
  def make_scored(age_days: nil, published_at: :unset, performance_multiple:)
    @seq += 1
    pub =
      if published_at != :unset
        published_at
      elsif age_days.nil?
        nil
      else
        Time.zone.today - age_days.days
      end
    video = @channel.videos.create!(
      youtube_video_id: "vid_#{@seq}",
      title: "영상 #{@seq}",
      is_short: false,
      published_at: pub
    )
    VideoScore.create!(video: video, performance_multiple: performance_multiple)
  end

  def evergreen?(score)
    score.reload.evergreen_candidate
  end

  test "후보 — 나이 200일 AND 배수 3(임계 180·2 동시 충족) → true" do
    s = make_scored(age_days: 200, performance_multiple: 3.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert evergreen?(s)
  end

  test "나이만 충족 — 나이 200일·배수 1.5(배수 미달) → false" do
    s = make_scored(age_days: 200, performance_multiple: 1.5)
    Scoring::DetermineEvergreen.new(@channel).call
    assert_not evergreen?(s)
  end

  test "배수만 충족 — 나이 100일·배수 5(나이 미달) → false" do
    s = make_scored(age_days: 100, performance_multiple: 5.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert_not evergreen?(s)
  end

  test "배수>1 로는 부족 — 나이 200일·배수 1.5 는 min_multiple 2 미만이라 false" do
    s = make_scored(age_days: 200, performance_multiple: 1.5)
    Scoring::DetermineEvergreen.new(@channel).call
    assert_not evergreen?(s), "배수 1.5 > 1 이지만 임계 2 미만이라 후보 아님"
  end

  test "나이 경계 — 정확히 180일·배수 2.0 은 포함 하한(>=)이라 true" do
    s = make_scored(age_days: MIN_AGE, performance_multiple: 2.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert evergreen?(s), "age == min_age·multiple == min_multiple 둘 다 포함 하한"
  end

  test "나이 경계 하단 — 179일·배수 5 → false(경계 미만)" do
    s = make_scored(age_days: MIN_AGE - 1, performance_multiple: 5.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert_not evergreen?(s)
  end

  test "published_at nil — 나이 미상이라 후보 아님(예외 없음)" do
    s = make_scored(published_at: nil, performance_multiple: 10.0)
    assert_nothing_raised { Scoring::DetermineEvergreen.new(@channel).call }
    assert_not evergreen?(s)
  end

  test "performance_multiple nil — 배수 미계산이라 후보 아님(예외 없음)" do
    s = make_scored(age_days: 300, performance_multiple: nil)
    assert_nothing_raised { Scoring::DetermineEvergreen.new(@channel).call }
    assert_not evergreen?(s)
  end

  test "Tokyo 경계 — UTC 늦은 밤이 Tokyo 로 다음 날짜인 발행일은 Tokyo 날짜로 경과일을 낸다" do
    # UTC 23:30 은 Asia/Tokyo(+9) 로 다음 날 08:30 — Tokyo 발행일은 UTC 날짜보다 하루 뒤.
    # 정확히 min_age 만큼 떨어진 Tokyo 발행일을 만들어 경계 포함(>=)이 Tokyo 날짜로 판정됨을 확인.
    tokyo_pub_date = Time.zone.today - MIN_AGE.days
    utc_late_night = tokyo_pub_date.to_time(:utc).change(hour: 23, min: 30) - 1.day
    # utc_late_night 의 Tokyo 날짜 == tokyo_pub_date 임을 사전 확인(테스트 전제 고정).
    assert_equal tokyo_pub_date, utc_late_night.in_time_zone.to_date
    assert_not_equal tokyo_pub_date, utc_late_night.to_date, "UTC 날짜는 하루 앞(경계 규약 차이 확인)"

    s = make_scored(published_at: utc_late_night, performance_multiple: 2.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert evergreen?(s), "Tokyo 날짜로 age == min_age 라 후보(포함 하한)"
  end

  test "재계산 — 이미 flag 가 있어도 같은 행을 갱신(중복 없음·값 갱신)" do
    s = make_scored(age_days: 200, performance_multiple: 3.0)
    Scoring::DetermineEvergreen.new(@channel).call
    assert evergreen?(s)

    # 배수를 임계 미만으로 낮추면 재실행이 같은 행의 flag 를 false 로 뒤집는다.
    s.update!(performance_multiple: 1.0)
    Scoring::DetermineEvergreen.new(@channel).call

    assert_not evergreen?(s), "재계산이 flag 를 갱신한다"
    assert_equal 1, VideoScore.where(video_id: s.video_id).count, "행 중복 없음(idempotent)"
  end

  test "스테이지 보존 — CalculatePerformance 재실행이 evergreen_candidate 를 건드리지 않는다(3컬럼만)" do
    # 실제 기준선→성과배수 스테이지로 배수를 물질화한 뒤 에버그린 판정.
    Baseline.create!(channel: @channel, video_type: "long", median_view_count: 100.0, sample_size: 10, low_confidence: false)
    video = @channel.videos.create!(
      youtube_video_id: "vid_stage",
      title: "보존",
      is_short: false,
      view_count: 300, # 300/100 = 3.0 배수
      published_at: Time.zone.today - 200.days
    )
    Scoring::CalculatePerformance.new(@channel).call
    Scoring::DetermineEvergreen.new(@channel).call

    score = VideoScore.find_by(video: video)
    assert score.evergreen_candidate, "후보 판정됨(나이 200·배수 3)"

    # performance 재실행 — evergreen_candidate 는 update! 대상 3컬럼이 아니라 보존돼야 한다.
    Scoring::CalculatePerformance.new(@channel).call
    assert score.reload.evergreen_candidate, "성과배수 재실행이 evergreen_candidate 를 보존"
  end
end
