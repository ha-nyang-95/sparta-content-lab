# Scoring::CalculateBaseline — 중앙값·홀짝·유형 미공유·nil 제외·저신뢰·표본0·결정성·idempotent·N상한 검증
require "test_helper"

class Scoring::CalculateBaselineTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "스코어링 채널", category: "직접경쟁", source: "seed")
    @seq = 0
    @base_time = Time.utc(2026, 1, 1, 0, 0, 0)
  end

  # view_count·is_short·published_at 을 가진 영상 생성. published_at 은 호출 순서대로 뒤로 밀려
  # 나중 생성일수록 더 최근(더 큰 id·더 최근 published_at)이 되도록 한다.
  def make_video(view_count:, is_short:, published_at: nil)
    @seq += 1
    @channel.videos.create!(
      youtube_video_id: "vid_#{@seq}",
      title: "영상 #{@seq}",
      view_count: view_count,
      is_short: is_short,
      published_at: published_at || (@base_time + @seq.hours)
    )
  end

  def baseline(video_type)
    Baseline.find_by(channel: @channel, video_type: video_type)
  end

  test "홀수 표본 롱폼 — 중앙값은 가운데 값, sample_size 는 표본 수" do
    [100, 500, 300, 900, 700].each { |v| make_video(view_count: v, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert_equal 500.0, b.median_view_count # 정렬 [100,300,500,700,900] 가운데
    assert_equal 5, b.sample_size
  end

  test "짝수 표본 롱폼 — 중앙값은 가운데 두 값의 평균(float 가능)" do
    [200, 400, 600, 900].each { |v| make_video(view_count: v, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert_equal 500.0, b.median_view_count # (400+600)/2
    assert_equal 4, b.sample_size
  end

  test "짝수 표본 — 소수점 나오는 실제 평균" do
    [100, 300].each { |v| make_video(view_count: v, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    assert_equal 200.0, baseline("long").median_view_count
  end

  test "쇼츠·롱폼 중앙값은 절대 공유하지 않는다 — 독립 행" do
    [1000, 2000, 3000].each { |v| make_video(view_count: v, is_short: true) }        # short median 2000
    [100, 200, 300, 400, 500].each { |v| make_video(view_count: v, is_short: false) } # long median 300
    Scoring::CalculateBaseline.new(@channel).call

    assert_equal 2000.0, baseline("short").median_view_count
    assert_equal 3, baseline("short").sample_size
    assert_equal 300.0, baseline("long").median_view_count
    assert_equal 5, baseline("long").sample_size
    assert_equal 2, Baseline.where(channel: @channel).count
  end

  test "view_count nil(회원 전용) 영상은 표본에서 제외" do
    [100, 200, 300, 400].each { |v| make_video(view_count: v, is_short: false) }
    2.times { make_video(view_count: nil, is_short: false) } # 회원 전용
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert_equal 4, b.sample_size            # nil 2개 제외
    assert_equal 250.0, b.median_view_count  # (200+300)/2
  end

  test "is_short nil(미분류) 영상은 표본에서 제외" do
    [100, 200, 300].each { |v| make_video(view_count: v, is_short: false) }
    make_video(view_count: 99999, is_short: nil) # 미분류 — 어느 유형에도 포함 안 됨
    Scoring::CalculateBaseline.new(@channel).call

    assert_equal 3, baseline("long").sample_size
    assert_equal 200.0, baseline("long").median_view_count
    assert_equal 0, baseline("short").sample_size
  end

  test "유형별 표본이 min_sample_for_confidence 미만이면 low_confidence=true(값은 계산)" do
    # min_sample_for_confidence 는 10. 5개만 넣는다.
    [100, 200, 300, 400, 500].each { |v| make_video(view_count: v, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert b.low_confidence
    assert_equal 300.0, b.median_view_count # 값은 계산됨
    assert_equal 5, b.sample_size
  end

  test "표본이 min_sample_for_confidence 이상이면 low_confidence=false" do
    12.times { |i| make_video(view_count: 100 + i, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    assert_not baseline("long").low_confidence
    assert_equal 12, baseline("long").sample_size
  end

  test "유형 공개 영상 0개 — median nil·sample_size 0·low_confidence true 로 안전 물질화" do
    Scoring::CalculateBaseline.new(@channel).call

    %w[short long].each do |type|
      b = baseline(type)
      assert_not_nil b, "#{type} 행이 물질화돼야 한다"
      assert_nil b.median_view_count
      assert_equal 0, b.sample_size
      assert b.low_confidence
    end
  end

  test "재계산 idempotent — 같은 행 갱신, 중복 행 생성 안 함" do
    [100, 200, 300].each { |v| make_video(view_count: v, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call
    first_long_id = baseline("long").id
    assert_equal 200.0, baseline("long").median_view_count

    # 영상 추가 후 재실행 → 같은 행이 갱신되고 행 수는 유지.
    make_video(view_count: 400, is_short: false)
    make_video(view_count: 500, is_short: false)
    Scoring::CalculateBaseline.new(@channel).call

    assert_equal 2, Baseline.where(channel: @channel).count # short + long, 중복 없음
    assert_equal first_long_id, baseline("long").id          # 같은 행
    assert_equal 300.0, baseline("long").median_view_count   # [100..500] 중앙값
    assert_equal 5, baseline("long").sample_size
  end

  test "N 상한 — 공개 영상이 N 초과여도 최근 N개(published_at desc)만 사용" do
    n = Scoring::Config.fetch(:baseline, :sample_size_n) # 25
    # 먼저 오래된 이상치 3개(더 이른 published_at) — 상한이 지켜지면 제외돼야 한다.
    3.times { make_video(view_count: 999_999, is_short: false, published_at: @base_time - 10.days) }
    # 이후 최근 N개 = 전부 500.
    n.times { make_video(view_count: 500, is_short: false) }
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert_equal n, b.sample_size          # 상한 = N
    assert_equal 500.0, b.median_view_count # 오래된 999_999 이상치 제외
  end

  test "결정성 — published_at 동률은 id desc 로 타이브레이크(가장 낮은 id 제외)" do
    n = Scoring::Config.fetch(:baseline, :sample_size_n) # 25
    same_time = @base_time
    # 가장 먼저 생성(가장 낮은 id) = 이상치 99999 → id desc 상한에서 제외돼야 한다.
    make_video(view_count: 99_999, is_short: false, published_at: same_time)
    # 이후 N개 값 1..N (모두 동일 published_at).
    (1..n).each { |v| make_video(view_count: v, is_short: false, published_at: same_time) }
    Scoring::CalculateBaseline.new(@channel).call

    b = baseline("long")
    assert_equal n, b.sample_size
    assert_equal ((1 + n) / 2).to_f, b.median_view_count # 1..25 중앙값 13, 99999 제외돼야 성립
  end

  test "자사 실측(200~4,100) 픽스처 — 중앙값·유형 미공유·nil 제외 동시 검증" do
    # 롱폼 공개 7개(홀수) — 자사 실측 대역. 정렬: [210,340,560,890,1250,2600,4100] 가운데 890.
    long_views = [1250, 210, 4100, 560, 2600, 340, 890]
    long_views.each { |v| make_video(view_count: v, is_short: false) }
    # 롱폼 회원 전용 2개(nil) — 제외돼야 한다.
    2.times { make_video(view_count: nil, is_short: false) }
    # 쇼츠 공개 4개(짝수) — 정렬 [800,1500,2200,3900] 가운데 두 값 평균 (1500+2200)/2 = 1850.
    short_views = [2200, 800, 3900, 1500]
    short_views.each { |v| make_video(view_count: v, is_short: true) }

    Scoring::CalculateBaseline.new(@channel).call

    long_b = baseline("long")
    assert_equal 7, long_b.sample_size         # nil 2개 제외
    assert_equal 890.0, long_b.median_view_count

    short_b = baseline("short")
    assert_equal 4, short_b.sample_size
    assert_equal 1850.0, short_b.median_view_count

    # 유형 미공유 — 중앙값이 서로 다름.
    assert_not_equal long_b.median_view_count, short_b.median_view_count
  end
end
