# Similarity::MatchOwnVideos — τ 경계·nil 방어·is_own 파티션·회원전용 포함·다대다·idempotent 재구축을 검증
require "test_helper"

class Similarity::MatchOwnVideosTest < ActiveSupport::TestCase
  setup do
    @own_channel = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @comp_channel = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @tau = Scoring::Config.fetch(:similarity, :tau)
    @seq = 0
  end

  # embedding(float 배열)을 packed-float BLOB 으로 저장한 영상 생성. vec 이 nil 이면 embedding 미설정.
  def make_video(channel, vec, view_count: 1000)
    @seq += 1
    video = channel.videos.create!(
      youtube_video_id: "vid_#{@seq}",
      title: "영상 #{@seq}",
      view_count: view_count
    )
    video.update!(embedding: vec.pack("f*")) if vec
    video
  end

  # 코사인 = cos_val 이 되도록 [1,0,0,0] 과 짝지을 벡터를 만든다(a=[1,0,..], b=[cos, sin,..]).
  def vec_with_cosine(cos_val)
    [cos_val, Math.sqrt(1.0 - cos_val * cos_val), 0.0, 0.0]
  end

  test "동일 임베딩(코사인 1.0 ≥ τ)은 OwnVideoMatch 를 생성한다" do
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call

    match = OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own.id)
    assert_not_nil match
    assert_in_delta 1.0, match.similarity, 1e-5
  end

  test "직교 임베딩(코사인 0 < τ)은 매칭하지 않는다" do
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@own_channel, [0.0, 1.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call

    assert_equal 0, OwnVideoMatch.count
  end

  test "τ 바로 위(0.9)는 매칭, τ 바로 아래(0.7)는 매칭 안 함" do
    assert_operator 0.9, :>=, @tau
    assert_operator 0.7, :<, @tau

    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own_above = make_video(@own_channel, vec_with_cosine(0.9))
    own_below = make_video(@own_channel, vec_with_cosine(0.7))

    Similarity::MatchOwnVideos.new.call

    assert_not_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own_above.id)
    assert_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own_below.id)
  end

  test "competitor 임베딩 nil 이면 예외 없이 매칭에서 제외된다" do
    make_video(@comp_channel, nil)
    make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])

    assert_nothing_raised { Similarity::MatchOwnVideos.new.call }
    assert_equal 0, OwnVideoMatch.count
  end

  test "own 임베딩 nil 이면 예외 없이 매칭에서 제외된다" do
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@own_channel, nil)

    assert_nothing_raised { Similarity::MatchOwnVideos.new.call }
    assert_equal 0, OwnVideoMatch.count
  end

  test "회원 전용 자사 영상(view_count nil)도 임베딩 있으면 매칭에 포함된다" do
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0], view_count: nil)
    assert_nil own.reload.view_count

    Similarity::MatchOwnVideos.new.call

    assert_not_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own.id)
  end

  test "자사↔자사·경쟁↔경쟁 쌍은 매칭하지 않는다(경쟁×자사만)" do
    make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call

    # 경쟁 2 × 자사 2 = 4 쌍만(자사끼리·경쟁끼리는 없음).
    assert_equal 4, OwnVideoMatch.count
  end

  test "경쟁 1개가 자사 2개와 유사하면 두 OwnVideoMatch 행이 생긴다" do
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own_a = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])
    own_b = make_video(@own_channel, vec_with_cosine(0.9))

    Similarity::MatchOwnVideos.new.call

    assert_equal 2, OwnVideoMatch.where(competitor_video_id: comp.id).count
    assert_not_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own_a.id)
    assert_not_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own_b.id)
  end

  test "재실행해도 매칭 집합이 같고 중복이 생기지 않는다(idempotent)" do
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call
    first = OwnVideoMatch.order(:competitor_video_id, :own_video_id).pluck(:competitor_video_id, :own_video_id)

    Similarity::MatchOwnVideos.new.call
    second = OwnVideoMatch.order(:competitor_video_id, :own_video_id).pluck(:competitor_video_id, :own_video_id)

    assert_equal first, second
    assert_equal 1, OwnVideoMatch.count
  end

  test "재실행 시 유사도가 τ 아래로 떨어진 스테일 매칭은 제거된다" do
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call
    assert_equal 1, OwnVideoMatch.count

    # own 임베딩을 τ 아래(0.7)로 바꾼 뒤 재구축하면 매칭이 사라진다.
    own.update!(embedding: vec_with_cosine(0.7).pack("f*"))
    Similarity::MatchOwnVideos.new.call

    assert_equal 0, OwnVideoMatch.count
    assert_nil OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own.id)
  end

  test "excluded 채널의 영상은 자사·경쟁 어느 쪽이든 매칭에서 제외된다" do
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])

    excluded_comp = Channel.create!(name: "제외 경쟁", category: "직접경쟁", source: "seed", is_own: false, excluded: true)
    make_video(excluded_comp, [1.0, 0.0, 0.0, 0.0])
    excluded_own = Channel.create!(name: "제외 자사", category: "직접경쟁", source: "seed", is_own: true, excluded: true)
    make_video(excluded_own, [1.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call

    # 정상 경쟁1 × 정상 자사1 = 1쌍만. excluded 채널 영상은 포함되지 않는다.
    assert_equal 1, OwnVideoMatch.count
  end

  test "한쪽 집합이 비면(임베딩 대기 등) 재구축을 건너뛰어 기존 매칭을 지우지 않는다" do
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    own = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])
    Similarity::MatchOwnVideos.new.call
    assert_equal 1, OwnVideoMatch.count

    # 자사 임베딩을 일시적으로 제거(수집 대기 시뮬) → own 집합 비어도 delete_all 이 돌면 안 된다.
    own.update!(embedding: nil)
    Similarity::MatchOwnVideos.new.call

    assert_equal 1, OwnVideoMatch.count, "own 집합이 비면 기존 매칭을 보존해야 한다(스테일 방지)"
  end

  test "비정규 벡터도 완전 코사인으로 올바르게 매칭한다(unit-norm 비가정)" do
    # ‖·‖≠1 인 벡터 두 개 — 방향이 같으면 코사인 1.0.
    comp = make_video(@comp_channel, [3.0, 0.0, 0.0, 0.0])
    own = make_video(@own_channel, [5.0, 0.0, 0.0, 0.0])

    Similarity::MatchOwnVideos.new.call

    match = OwnVideoMatch.find_by(competitor_video_id: comp.id, own_video_id: own.id)
    assert_not_nil match, "분모를 계산하는 완전 코사인이면 비정규 동방향 벡터도 코사인 1.0"
    assert_in_delta 1.0, match.similarity, 1e-5
  end
end
