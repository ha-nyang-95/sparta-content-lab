# 대시보드 홈 — 200·읽기 전용·추천 렌더·필터 화이트리스트 폴백·금지 라벨 부재 검증
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @channel = Channel.create!(name: "韓国語の森 with Aki", category: "직접경쟁", source: "seed", subscriber_count: 1_860_000)
    @video = @channel.videos.create!(youtube_video_id: "vid_#{SecureRandom.hex(4)}", title: "日本人がよく間違える 助詞", view_count: 182_563, is_short: false, published_at: 5.days.ago)
    VideoScore.create!(video: @video, performance_multiple: 2.9, own_match_count: 0, needs_verification: false, rank_eligible: true)
    @rec = Recommendation.create!(topic_label: "일본인이 자주 틀리는 한국어 조사 5가지", opportunity_score: 89.0, rank: 1, reference_video_ids: [@video.id])
  end

  test "GET root 200" do
    get root_path
    assert_response :success
  end

  test "추천이 있으면 topic_label 과 기회 점수를 렌더한다" do
    get root_path
    assert_response :success
    assert_includes @response.body, "일본인이 자주 틀리는 한국어 조사 5가지"
    assert_includes @response.body, "기회 점수"
  end

  test "읽기 전용 — GET 이 Recommendation 을 쓰지 않는다" do
    before = Recommendation.count
    get root_path
    assert_equal before, Recommendation.count
  end

  test "?period=1m 와 ?category 는 200(화이트리스트 안전)" do
    get root_path(period: "1m", category: "한국어교육일반")
    assert_response :success
    get root_path(type: "short", layout: "flat")
    assert_response :success
  end

  test "잘못된 period 는 안전 폴백(200)" do
    get root_path(period: "xxx", category: "drop; --", layout: "zzz")
    assert_response :success
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get root_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end

  test "요약 위젯 — 스냅샷이 얕아도 최선 데이터(급상승 배수)를 보여주고 하단에 안내 문구를 단다" do
    # setup 의 @video/@score(rank_eligible)가 급상승 위젯에 뜨고, 스냅샷 0일이라 안내 문구가 붙는다.
    get root_path
    assert_response :success
    assert_includes @response.body, @video.title, "급상승 위젯이 최선 데이터(영상 제목)를 렌더"
    assert_includes @response.body, "최적화된 결과는 아닙니다", "수집 기간 짧을 때 안내 문구"
    # '데이터 수집 중'만 뜨고 콘텐츠는 없던 예전 상태가 아니어야 한다(위젯이 내용을 가짐).
  end

  test "에버그린 후보가 있으면 섹션에 제목과 뱃지를 렌더한다" do
    make_evergreen("에버그린 후보 콘텐츠", multiple: 4.5)
    get root_path
    assert_response :success
    assert_includes @response.body, "에버그린 후보 콘텐츠"
    # 스냅샷 없음(<14) → 후보 ghost 뱃지.
    assert_includes @response.body, "에버그린 후보"
  end

  test "에버그린 후보가 없어도 섹션은 유지되고 200(위젯 숨김 없음)" do
    get root_path
    assert_response :success
    assert_includes @response.body, "에버그린 콘텐츠"
  end

  test "읽기 전용 — GET 이 VideoScore 를 쓰지 않는다" do
    make_evergreen("에버그린 후보 콘텐츠", multiple: 4.5)
    before = VideoScore.count
    get root_path
    assert_equal before, VideoScore.count
  end

  test "스냅샷 충분(>=14일)하나 후보 0 이면 빈 void 대신 자리 유지 안내(§4.7)" do
    # 14 distinct 날짜 스냅샷 → widget_collecting? false. 에버그린 후보는 없음.
    14.times { |i| @video.daily_stats.create!(date: (i + 1).days.ago.to_date, view_count: 1000 + i) }
    get root_path
    assert_response :success
    assert_includes @response.body, "에버그린 후보가 아직 없습니다.", "heading-only void 금지 — 빈 상태 자리 유지"
  end

  private

  # evergreen_candidate=true 영상+스코어 생성(대시보드 섹션 픽스처).
  def make_evergreen(title, multiple:)
    video = @channel.videos.create!(youtube_video_id: "evg_#{SecureRandom.hex(4)}", title: title,
                                    view_count: 90_000, is_short: false, published_at: 200.days.ago)
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: 0,
                       needs_verification: false, rank_eligible: true, evergreen_candidate: true)
    video
  end
end
