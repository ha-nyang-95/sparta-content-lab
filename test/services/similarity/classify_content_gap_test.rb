# Similarity::ClassifyContentGap — 4구간 경계(0/1/2/saturation_min)·경쟁만·excluded 제외·idempotent·스테이지 보존을 검증
require "test_helper"

class Similarity::ClassifyContentGapTest < ActiveSupport::TestCase
  setup do
    @own_channel = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @comp_channel = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @sat = Scoring::Config.fetch(:content_gap, :saturation_min)
    @seq = 0
  end

  def make_video(channel)
    @seq += 1
    channel.videos.create!(youtube_video_id: "vid_#{@seq}", title: "영상 #{@seq}", view_count: 1000)
  end

  # 경쟁 영상 + 그 VideoScore 를 만들고, 자사 영상 n개를 매칭(OwnVideoMatch)으로 붙인다.
  def competitor_with_matches(n)
    comp = make_video(@comp_channel)
    score = VideoScore.create!(video: comp, performance_multiple: 1.0, rank_eligible: true)
    add_matches(comp, n)
    [comp, score]
  end

  def add_matches(comp, n)
    n.times do
      own = make_video(@own_channel)
      OwnVideoMatch.create!(competitor_video: comp, own_video: own, similarity: 0.9)
    end
  end

  test "매치 0개 경쟁 영상은 not_made 로 분류된다(nil 아님)" do
    _comp, score = competitor_with_matches(0)

    Similarity::ClassifyContentGap.new.call

    assert_equal "not_made", score.reload.content_gap_bucket
  end

  test "매치 1개는 one 으로 분류된다" do
    _comp, score = competitor_with_matches(1)

    Similarity::ClassifyContentGap.new.call

    assert_equal "one", score.reload.content_gap_bucket
  end

  test "개수(own_match_count)가 버킷과 같은 행에 함께 물질화된다(FR-18 일치 — 급상승 행 N개 소재지)" do
    _comp, score = competitor_with_matches(2)

    Similarity::ClassifyContentGap.new.call

    score.reload
    assert_equal 2, score.own_match_count, "급상승 행 'N개'가 읽을 개수가 같은 VideoScore 에 저장된다"
    assert_equal "few", score.content_gap_bucket
  end

  test "매치 0개는 own_match_count 0 으로 물질화된다(nil 아님)" do
    _comp, score = competitor_with_matches(0)

    Similarity::ClassifyContentGap.new.call

    assert_equal 0, score.reload.own_match_count
  end

  test "content_gap_bucket 은 화이트리스트 밖 값이면 무효다(classify 오타 방어)" do
    _comp, score = competitor_with_matches(1)
    score.content_gap_bucket = "saturatd" # 오타
    assert_not score.valid?
    assert score.errors[:content_gap_bucket].any?
  end

  test "매치 2개는 few 로 분류된다" do
    _comp, score = competitor_with_matches(2)

    Similarity::ClassifyContentGap.new.call

    assert_equal "few", score.reload.content_gap_bucket
  end

  test "매치 = saturation_min 은 saturated 로 분류된다(포함 하한 >=)" do
    _comp, score = competitor_with_matches(@sat)

    Similarity::ClassifyContentGap.new.call

    assert_equal "saturated", score.reload.content_gap_bucket
  end

  test "매치 = saturation_min - 1 은 few 로 분류된다(포화 미달 경계)" do
    _comp, score = competitor_with_matches(@sat - 1)

    Similarity::ClassifyContentGap.new.call

    assert_equal "few", score.reload.content_gap_bucket
  end

  test "자사 영상의 VideoScore 는 분류 대상이 아니다(content_gap_bucket nil 유지)" do
    own = make_video(@own_channel)
    own_score = VideoScore.create!(video: own, performance_multiple: 1.0, rank_eligible: true)

    Similarity::ClassifyContentGap.new.call

    assert_nil own_score.reload.content_gap_bucket
  end

  test "excluded 경쟁 채널의 영상은 분류하지 않는다(bucket nil 유지)" do
    excluded_comp = Channel.create!(name: "제외 경쟁", category: "직접경쟁", source: "seed", is_own: false, excluded: true)
    vid = excluded_comp.videos.create!(youtube_video_id: "excl_vid", title: "제외 영상", view_count: 1000)
    score = VideoScore.create!(video: vid, performance_multiple: 1.0, rank_eligible: true)

    Similarity::ClassifyContentGap.new.call

    assert_nil score.reload.content_gap_bucket
  end

  test "재실행해도 같은 버킷이고, 매치가 1→2 로 늘면 one→few 로 갱신된다(idempotent·재계산)" do
    comp, score = competitor_with_matches(1)

    Similarity::ClassifyContentGap.new.call
    assert_equal "one", score.reload.content_gap_bucket

    Similarity::ClassifyContentGap.new.call
    assert_equal "one", score.reload.content_gap_bucket

    add_matches(comp, 1) # 1 → 2
    Similarity::ClassifyContentGap.new.call
    assert_equal "few", score.reload.content_gap_bucket
  end

  test "performance 재실행(성과 컬럼만 update!)에도 content_gap_bucket 이 보존된다(스테이지 보존)" do
    comp, score = competitor_with_matches(1)
    Similarity::ClassifyContentGap.new.call
    assert_equal "one", score.reload.content_gap_bucket

    # 3.2 CalculatePerformance 스타일 — 성과 3컬럼만 update! (content_gap_bucket 미언급).
    VideoScore.find_or_initialize_by(video: comp).update!(
      performance_multiple: 5.0, rank_eligible: true, needs_verification: false
    )

    assert_equal "one", score.reload.content_gap_bucket
    assert_in_delta 5.0, score.performance_multiple, 1e-6
  end
end
