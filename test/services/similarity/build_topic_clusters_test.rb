# Similarity::BuildTopicClusters — 리더(중심) 클러스터링·체이닝 방지·τ 경계·nil/excluded 제외·고립·휘발 재구축·교차·결정성 검증
require "test_helper"

class Similarity::BuildTopicClustersTest < ActiveSupport::TestCase
  setup do
    @own_channel = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @comp_channel = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @tau = Scoring::Config.fetch(:similarity, :cluster_tau)
    @seq = 0
  end

  # 2D 단위벡터를 각도(도)로 생성 — 두 벡터 코사인 = cos(각도차). 체이닝 테스트용.
  def vec_at(deg)
    r = deg * Math::PI / 180.0
    [Math.cos(r), Math.sin(r), 0.0]
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

  # 코사인 = cos_val 이 되도록 [1,0,0,0] 과 짝지을 벡터를 만든다.
  def vec_with_cosine(cos_val)
    [cos_val, Math.sqrt(1.0 - cos_val * cos_val), 0.0, 0.0]
  end

  test "연결요소: A~B~C 유사·D 직교면 {A,B,C} 한 클러스터·D 는 클러스터 없음" do
    a = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    b = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    c = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    d = make_video(@comp_channel, [0.0, 1.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call

    cid = a.reload.topic_cluster_id
    assert_not_nil cid
    assert_equal cid, b.reload.topic_cluster_id
    assert_equal cid, c.reload.topic_cluster_id
    assert_nil d.reload.topic_cluster_id
    assert_equal 1, TopicCluster.count
    assert_equal 3, TopicCluster.find(cid).size
  end

  test "체이닝 방지: 그라디언트 체인(A~B~C~D, 인접 0.906·간격 0.79)을 중심 게이트로 {A,B}·{C,D}로 분리" do
    # 25°씩 벌린 4개 — 인접 코사인 cos25≈0.906(≥cluster_tau 0.88), 한 칸 건너 cos50≈0.643.
    # 단일연결이면 인접 간선으로 {A,B,C,D} 한 덩어리(체이닝). 리더(중심)면 중심에서 벌어져 2개로 분리.
    a = make_video(@comp_channel, vec_at(0))
    b = make_video(@comp_channel, vec_at(25))
    c = make_video(@comp_channel, vec_at(50))
    d = make_video(@comp_channel, vec_at(75))

    Similarity::BuildTopicClusters.new.call

    assert_equal 2, TopicCluster.count, "체이닝으로 한 덩어리가 되지 않고 2개 클러스터로 분리돼야 한다"
    assert_equal a.reload.topic_cluster_id, b.reload.topic_cluster_id, "{A,B} 한 클러스터"
    assert_equal c.reload.topic_cluster_id, d.reload.topic_cluster_id, "{C,D} 한 클러스터"
    assert_not_nil a.topic_cluster_id
    assert_not_equal a.topic_cluster_id, c.topic_cluster_id, "{A,B}와 {C,D}는 다른 클러스터"
  end

  test "τ 경계: 동일(코사인 1.0 ≥ τ)은 묶고, 직교(코사인 0 < τ)는 안 묶는다" do
    x = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    y = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    z = make_video(@comp_channel, [0.0, 1.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call

    assert_not_nil x.reload.topic_cluster_id
    assert_equal x.topic_cluster_id, y.reload.topic_cluster_id
    assert_nil z.reload.topic_cluster_id
    assert_equal 1, TopicCluster.count
  end

  test "고립 영상: 유사 짝이 없으면 클러스터로 물질화하지 않는다" do
    lonely = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call

    assert_nil lonely.reload.topic_cluster_id
    assert_equal 0, TopicCluster.count
  end

  test "임베딩 nil 영상은 예외 없이 대상에서 제외된다" do
    pair_a = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    pair_b = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    no_embed = make_video(@comp_channel, nil)

    assert_nothing_raised { Similarity::BuildTopicClusters.new.call }

    assert_not_nil pair_a.reload.topic_cluster_id
    assert_equal pair_a.topic_cluster_id, pair_b.reload.topic_cluster_id
    assert_nil no_embed.reload.topic_cluster_id
    assert_equal 1, TopicCluster.count
  end

  test "excluded 채널 영상은 유사해도 묶기에서 제외된다" do
    excluded = Channel.create!(name: "제외 채널", category: "직접경쟁", source: "seed", excluded: true)
    inc_a = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    inc_b = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    exc = make_video(excluded, [1.0, 0.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call

    assert_nil exc.reload.topic_cluster_id
    cid = inc_a.reload.topic_cluster_id
    assert_not_nil cid
    assert_equal cid, inc_b.reload.topic_cluster_id
    assert_equal 2, TopicCluster.find(cid).size, "excluded 영상은 클러스터 크기에 포함되지 않는다"
  end

  test "휘발 재구축: 재실행해도 클러스터가 누적되지 않고, 그래프 변화가 반영된다" do
    a = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    b = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call
    assert_equal 1, TopicCluster.count

    Similarity::BuildTopicClusters.new.call
    assert_equal 1, TopicCluster.count, "재실행해도 클러스터가 누적되지 않는다(휘발)"

    # b 임베딩을 τ 아래(직교)로 바꾸면 간선이 사라져 클러스터가 없어진다.
    b.update!(embedding: [0.0, 1.0, 0.0, 0.0].pack("f*"))
    Similarity::BuildTopicClusters.new.call

    assert_equal 0, TopicCluster.count, "그래프에서 간선이 사라지면 옛 클러스터는 재구축으로 제거된다"
    assert_nil a.reload.topic_cluster_id
    assert_nil b.reload.topic_cluster_id
  end

  test "교차 묶기: 자사·경쟁 영상이 유사하면 한 클러스터로 함께 묶인다" do
    own = make_video(@own_channel, [1.0, 0.0, 0.0, 0.0])
    comp = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call

    cid = own.reload.topic_cluster_id
    assert_not_nil cid
    assert_equal cid, comp.reload.topic_cluster_id
    assert_equal 1, TopicCluster.count
  end

  test "결정성: 같은 그래프를 두 번 돌리면 클러스터별 멤버 집합이 동일하다" do
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    make_video(@comp_channel, [0.0, 1.0, 0.0, 0.0])
    make_video(@comp_channel, [0.0, 1.0, 0.0, 0.0])

    Similarity::BuildTopicClusters.new.call
    first = membership_sets

    Similarity::BuildTopicClusters.new.call
    second = membership_sets

    assert_equal first, second
  end

  # 클러스터별 멤버 video_id 집합을 정렬된 배열의 집합으로 반환(클러스터 id 무관 비교).
  def membership_sets
    Video.where.not(topic_cluster_id: nil)
      .pluck(:topic_cluster_id, :id)
      .group_by(&:first)
      .values
      .map { |rows| rows.map(&:last).sort }
      .sort
  end
  test "임베딩이 전량 부재하면(일시) 기존 클러스터를 지우지 않고 건너뛴다" do
    a = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    b = make_video(@comp_channel, [1.0, 0.0, 0.0, 0.0])
    Similarity::BuildTopicClusters.new.call
    assert_equal 1, TopicCluster.count

    # 임베딩을 일시 제거(수집 대기 시뮬) → units 비어도 delete_all 이 돌면 안 된다.
    a.update!(embedding: nil)
    b.update!(embedding: nil)
    Similarity::BuildTopicClusters.new.call

    assert_equal 1, TopicCluster.count, "임베딩 전량 부재 시 기존 클러스터를 보존해야 한다(스테일 방지)"
  end

end
