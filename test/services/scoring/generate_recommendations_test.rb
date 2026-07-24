# Scoring::GenerateRecommendations — 상위 선정·정직성·결정적 동점(성과·최신성·id)·스냅샷 FK 없음·직렬화·topic_label·재생성 검증
require "test_helper"

class Scoring::GenerateRecommendationsTest < ActiveSupport::TestCase
  MAX_COUNT = Scoring::Config.fetch(:recommendation, :max_count)

  setup do
    @own = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @competitor = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @seq = 0
  end

  # opportunity_score 직접 지정한 클러스터 + 경쟁 멤버 구성(멤버: channel/multiple/age_days/published_at).
  def make_cluster(opportunity_score:, members: [{ multiple: 3.0, age_days: 10 }])
    cluster = TopicCluster.create!(size: members.size, opportunity_score: opportunity_score)
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
      VideoScore.create!(video: video, performance_multiple: m[:multiple]) if m.key?(:multiple)
    end
    cluster
  end

  test "상위 N 선정 — 자격 클러스터가 max_count 초과면 기회 점수 상위 max_count개만 rank 내림차순으로 생성" do
    (MAX_COUNT + 2).times { |i| make_cluster(opportunity_score: (i + 1) * 10.0) }
    Scoring::GenerateRecommendations.new.call

    assert_equal MAX_COUNT, Recommendation.count
    recs = Recommendation.order(:rank).to_a
    assert_equal (1..MAX_COUNT).to_a, recs.map(&:rank)
    scores = recs.map(&:opportunity_score)
    assert_equal scores.sort.reverse, scores, "기회 점수 내림차순으로 rank 부여"
    assert_operator scores.min, :>, 0.0
  end

  test "정직성 — 자격 클러스터가 max_count 미만이면 그 수만 생성(억지 채우기 없음)" do
    skip "max_count 가 2 이하라 이 케이스가 무의미" if MAX_COUNT < 3
    make_cluster(opportunity_score: 50.0)
    make_cluster(opportunity_score: 30.0)
    Scoring::GenerateRecommendations.new.call

    assert_equal 2, Recommendation.count
  end

  test "자격 0 — opportunity_score > 0 클러스터가 없으면 Recommendation 0개" do
    make_cluster(opportunity_score: 0.0)
    make_cluster(opportunity_score: 0.0)
    Scoring::GenerateRecommendations.new.call

    assert_equal 0, Recommendation.count
  end

  test "동점 성과 — 기회 점수 같고 성과 배수 다르면 배수 높은 클러스터 먼저" do
    low  = make_cluster(opportunity_score: 40.0, members: [{ multiple: 2.0, age_days: 10 }])
    high = make_cluster(opportunity_score: 40.0, members: [{ multiple: 9.0, age_days: 10 }])
    Scoring::GenerateRecommendations.new.call

    rank1 = Recommendation.find_by(rank: 1)
    assert_equal high.videos.map(&:id).sort, rank1.reference_video_ids
    refute_equal low.videos.map(&:id).sort, rank1.reference_video_ids
  end

  test "동점 최신성 — 기회·성과 같고 최신성 다르면 최근 발행 클러스터 먼저" do
    older  = make_cluster(opportunity_score: 40.0, members: [{ multiple: 5.0, age_days: 30 }])
    newer  = make_cluster(opportunity_score: 40.0, members: [{ multiple: 5.0, age_days: 2 }])
    Scoring::GenerateRecommendations.new.call

    rank1 = Recommendation.find_by(rank: 1)
    assert_equal newer.videos.map(&:id).sort, rank1.reference_video_ids
    refute_equal older.videos.map(&:id).sort, rank1.reference_video_ids
  end

  test "완전 결정 — 모두 동점이면 클러스터 id 오름차순" do
    first  = make_cluster(opportunity_score: 40.0, members: [{ multiple: 5.0, age_days: 10 }])
    second = make_cluster(opportunity_score: 40.0, members: [{ multiple: 5.0, age_days: 10 }])
    assert_operator first.id, :<, second.id
    Scoring::GenerateRecommendations.new.call

    rank1 = Recommendation.find_by(rank: 1)
    assert_equal first.videos.map(&:id).sort, rank1.reference_video_ids
  end

  test "스냅샷 — 클러스터를 재구축(nullify + delete)해도 추천의 reference_video_ids·topic_label 보존(FK 없음)" do
    cluster = make_cluster(opportunity_score: 60.0, members: [{ multiple: 7.0, age_days: 5 }])
    Scoring::GenerateRecommendations.new.call
    rec = Recommendation.find_by(rank: 1)
    saved_ids = rec.reference_video_ids
    saved_label = rec.topic_label
    assert_not_empty saved_ids

    # 휘발 클러스터 재구축 시뮬레이션 — 멤버 nullify 후 클러스터 삭제.
    Video.where(topic_cluster_id: cluster.id).update_all(topic_cluster_id: nil)
    assert_nothing_raised { TopicCluster.delete_all }

    rec.reload
    assert_equal saved_ids, rec.reference_video_ids, "스냅샷은 클러스터 소멸에도 유효"
    assert_equal saved_label, rec.topic_label
  end

  test "직렬화 — reference_video_ids 는 경쟁 영상 id 의 Array 로 왕복" do
    cluster = make_cluster(opportunity_score: 50.0, members: [
      { channel: @competitor, multiple: 4.0, age_days: 10 },
      { channel: @own, multiple: 9.0, age_days: 1 } # 자사는 참고 영상에서 제외
    ])
    Scoring::GenerateRecommendations.new.call
    rec = Recommendation.order(:rank).first.reload

    competitor_ids = cluster.videos.reject { |v| v.channel.is_own }.map(&:id).sort
    assert_kind_of Array, rec.reference_video_ids
    assert_equal competitor_ids, rec.reference_video_ids
    assert(rec.reference_video_ids.all? { |id| id.is_a?(Integer) })
  end

  test "topic_label — 성과 배수 최고 경쟁 멤버의 제목" do
    make_cluster(opportunity_score: 50.0, members: [
      { channel: @competitor, multiple: 2.0, age_days: 10 },
      { channel: @competitor, multiple: 8.0, age_days: 10 }, # 최고 배수 → 이 제목
      { channel: @competitor, multiple: 5.0, age_days: 10 }
    ])
    Scoring::GenerateRecommendations.new.call

    top_score = VideoScore.order(performance_multiple: :desc).first
    assert_equal top_score.video.title, Recommendation.find_by(rank: 1).topic_label
  end

  test "재생성 idempotent — 두 번 실행해도 누적 없이 같은 추천" do
    make_cluster(opportunity_score: 50.0)
    make_cluster(opportunity_score: 30.0)
    Scoring::GenerateRecommendations.new.call
    first = Recommendation.order(:rank).map { |r| [r.rank, r.topic_label, r.opportunity_score, r.reference_video_ids] }

    Scoring::GenerateRecommendations.new.call
    second = Recommendation.order(:rank).map { |r| [r.rank, r.topic_label, r.opportunity_score, r.reference_video_ids] }

    assert_equal 2, Recommendation.count, "delete_all 재구축 — 누적 없음"
    assert_equal first, second
  end
  test "상류 기회 점수 스테이지 실패(클러스터 점수 NULL) 시 기존 추천을 지우지 않고 건너뛴다" do
    # 정상 실행으로 추천을 만든다.
    make_cluster(opportunity_score: 50.0)
    Scoring::GenerateRecommendations.new.call
    assert_equal 1, Recommendation.count

    # 클러스터를 재구축(점수 NULL) 상황 시뮬 — 4.4가 새 클러스터를 만들고 5.1이 실패해 점수 미계산.
    TopicCluster.update_all(opportunity_score: nil)
    Scoring::GenerateRecommendations.new.call

    assert_equal 1, Recommendation.count, "점수가 전부 NULL(상류 실패)이면 기존 추천을 보존해야 한다(스테일 방지)"
  end

  test "정직한 자격 0(점수 계산됐으나 아무도 >0)은 추천을 지운다(스테일 표시 금지)" do
    make_cluster(opportunity_score: 50.0)
    Scoring::GenerateRecommendations.new.call
    assert_equal 1, Recommendation.count

    # 점수는 계산됐으나(0.0) 아무도 자격 없음 → 정직하게 0개.
    TopicCluster.update_all(opportunity_score: 0.0)
    Scoring::GenerateRecommendations.new.call

    assert_equal 0, Recommendation.count, "자격 0(점수 계산됨)은 정직하게 추천 0개"
  end

  test "topic_label 폴백 — 최고 경쟁 영상 제목이 nil 이어도 자사 영상 제목을 쓰지 않는다(경쟁 내 폴백)" do
    cluster = TopicCluster.create!(size: 2, opportunity_score: 40.0)
    # 최고 성과 경쟁 영상은 제목 nil, 다른 경쟁 영상은 제목 있음.
    top = @competitor.videos.create!(youtube_video_id: "c_top", title: nil, is_short: false, topic_cluster: cluster)
    VideoScore.create!(video: top, performance_multiple: 9.0)
    @competitor.videos.create!(youtube_video_id: "c_other", title: "경쟁 주제 제목", is_short: false, topic_cluster: cluster)
    # 자사 영상(낮은 id 아님·있어도 라벨 안 됨).
    own = @own.videos.create!(youtube_video_id: "o_1", title: "자사 영상 제목", is_short: false, topic_cluster: cluster)
    VideoScore.create!(video: own, performance_multiple: 20.0)

    Scoring::GenerateRecommendations.new.call

    label = Recommendation.first.topic_label
    refute_equal "자사 영상 제목", label, "자사 영상 제목이 주제명이 되면 안 된다"
    assert_equal "경쟁 주제 제목", label
  end

end
