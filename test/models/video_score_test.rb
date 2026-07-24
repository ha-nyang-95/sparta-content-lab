# VideoScore 검증 — belongs_to :video 필수·video_id 유니크(영상 1:1, 중복 행 금지)
require "test_helper"

class VideoScoreTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "점수용 채널", category: "직접경쟁", source: "seed")
    @video = @channel.videos.create!(youtube_video_id: "vid_score_1", title: "영상", view_count: 100, is_short: false)
  end

  test "video 가 없으면 유효하지 않다" do
    score = VideoScore.new
    assert_not score.valid?
    assert score.errors[:video].any?
  end

  test "video 가 있으면 저장된다" do
    score = VideoScore.new(video: @video)
    assert score.valid?, score.errors.full_messages.to_sentence
  end

  test "video_id 는 유니크해야 한다 — 같은 영상 두 번째 점수는 무효" do
    VideoScore.create!(video: @video)
    dup = VideoScore.new(video: @video)
    assert_not dup.valid?
    assert dup.errors[:video_id].any?
  end

  # --- ranked 스코프 (기본 정렬키) ---

  # 배수·조회수를 명시 지정한 영상+점수를 만든다.
  def make_scored(multiple:, view_count:, rank_eligible: true)
    @vseq = (@vseq || 0) + 1
    video = @channel.videos.create!(
      youtube_video_id: "vid_rank_#{@vseq}",
      title: "영상 #{@vseq}",
      view_count: view_count,
      is_short: false
    )
    VideoScore.create!(video: video, performance_multiple: multiple, rank_eligible: rank_eligible, needs_verification: false)
  end

  test "ranked — 성과 배수 내림차순(5,3,2)" do
    s2 = make_scored(multiple: 2.0, view_count: 100)
    s5 = make_scored(multiple: 5.0, view_count: 100)
    s3 = make_scored(multiple: 3.0, view_count: 100)
    assert_equal [s5.id, s3.id, s2.id], VideoScore.ranked.pluck(:id)
  end

  test "ranked — raw 조회수 정렬이 아니라 성과 배수 정렬이다" do
    # 조회수 큰 순 ≠ 배수 큰 순: 최대 조회수 영상이 최소 배수를 갖게 한다.
    low_multiple_high_view = make_scored(multiple: 1.5, view_count: 100_000)
    high_multiple_low_view = make_scored(multiple: 8.0, view_count: 500)
    ordered = VideoScore.ranked.pluck(:id)
    assert_equal [high_multiple_low_view.id, low_multiple_high_view.id], ordered,
      "배수 기준으로 정렬해야 한다 — 조회수가 아니다"
  end

  test "ranked — 배수 동률이면 video_id 오름차순으로 결정적 정렬" do
    a = make_scored(multiple: 4.0, view_count: 100)
    b = make_scored(multiple: 4.0, view_count: 100)
    expected = [a.video_id, b.video_id].sort
    assert_equal expected, VideoScore.ranked.pluck(:video_id)
  end

  test "ranked — rank_eligible=false와 nil 배수는 제외된다" do
    kept = make_scored(multiple: 3.0, view_count: 100)
    make_scored(multiple: 1.0, view_count: 100, rank_eligible: false)
    # nil 배수는 항상 rank_eligible false(3.2 보장)
    make_scored(multiple: nil, view_count: 100, rank_eligible: false)
    assert_equal [kept.id], VideoScore.ranked.pluck(:id)
  end

  test "ranked — 3.2 불변식이 깨져 rank_eligible=true 인데 배수 nil 이어도 방어적으로 제외" do
    kept = make_scored(multiple: 3.0, view_count: 100)
    # 불변식 위반 데이터(백필·회귀)를 가정 — ranked 는 성과 배수 정렬 축이라 NULL 을 명시 제외한다.
    make_scored(multiple: nil, view_count: 100, rank_eligible: true)
    assert_equal [kept.id], VideoScore.ranked.pluck(:id)
  end
end
