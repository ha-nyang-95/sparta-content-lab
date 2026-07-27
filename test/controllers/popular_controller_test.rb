# 인기 콘텐츠 — 200·읽기 전용·성과 배수 desc 정렬·필터(유형·카테고리·에버그린)·금지 라벨 부재 검증
require "test_helper"

class PopularControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @channel = Channel.create!(name: "韓国語の森 with Aki", category: "직접경쟁", source: "seed", subscriber_count: 1_860_000)

    @high = make_scored("높은 배수 롱폼", multiple: 9.0, is_short: false, own_match_count: 0)
    @low  = make_scored("낮은 배수 롱폼", multiple: 2.5, is_short: false, own_match_count: 1)
    @short = make_scored("쇼츠 영상", multiple: 4.0, is_short: true, own_match_count: 2)
  end

  def make_scored(title, multiple:, is_short:, own_match_count:, channel: @channel, published_at: 2.days.ago, evergreen: false, view_count: 120_000)
    video = channel.videos.create!(
      youtube_video_id: "vid_#{SecureRandom.hex(4)}",
      title: title, view_count: view_count, is_short: is_short, published_at: published_at
    )
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: own_match_count,
                       needs_verification: false, rank_eligible: true, evergreen_candidate: evergreen)
    video
  end

  test "GET /popular 200" do
    get popular_path
    assert_response :success
  end

  test "성과 배수 desc 로 정렬해 렌더한다" do
    get popular_path
    assert_response :success
    body = @response.body
    assert_operator body.index("높은 배수 롱폼"), :<, body.index("낮은 배수 롱폼"), "9.0배가 2.5배보다 위"
  end

  test "?type=short 는 쇼츠만" do
    get popular_path(type: "short")
    assert_response :success
    assert_includes @response.body, "쇼츠 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "?type=long 는 롱폼만" do
    get popular_path(type: "long")
    assert_response :success
    assert_includes @response.body, "높은 배수 롱폼"
    assert_not_includes @response.body, "쇼츠 영상"
  end

  test "?category 는 그 카테고리 채널만" do
    other = Channel.create!(name: "다른 채널", category: "한국어교육일반", source: "seed", subscriber_count: 5_000)
    make_scored("타 카테고리 영상", multiple: 8.0, is_short: false, own_match_count: 0, channel: other)
    get popular_path(category: "한국어교육일반")
    assert_response :success
    assert_includes @response.body, "타 카테고리 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "?period=evergreen 는 에버그린 후보만" do
    make_scored("에버그린 후보 영상", multiple: 3.0, is_short: false, own_match_count: 0, published_at: 300.days.ago, evergreen: true)
    get popular_path(period: "evergreen")
    assert_response :success
    assert_includes @response.body, "에버그린 후보 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "excluded 채널은 제외한다" do
    excl = Channel.create!(name: "제외 채널", category: "직접경쟁", source: "seed", subscriber_count: 9_000, excluded: true)
    make_scored("제외 영상", multiple: 20.0, is_short: false, own_match_count: 0, channel: excl)
    get popular_path
    assert_response :success
    assert_not_includes @response.body, "제외 영상"
  end

  test "읽기 전용 — GET 이 VideoScore 를 쓰지 않는다" do
    before = VideoScore.count
    get popular_path
    assert_equal before, VideoScore.count
  end

  test "잘못된 파라미터는 안전 폴백(200)" do
    get popular_path(period: "xxx", category: "drop; --", type: "zzz", layout: "qqq")
    assert_response :success
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get popular_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end

  test "에버그린 탭은 후보 행에 에버그린 뱃지를 표시한다" do
    make_scored("에버그린 뱃지 영상", multiple: 3.0, is_short: false, own_match_count: 0, published_at: 2.days.ago, evergreen: true)
    get popular_path(period: "evergreen")
    assert_response :success
    assert_includes @response.body, "에버그린 뱃지 영상"
    # 스냅샷 없음(<14) → 후보 ghost 뱃지.
    assert_includes @response.body, "에버그린 후보"
  end

  test "타 기간 탭(1w)에는 에버그린 뱃지를 표시하지 않는다" do
    make_scored("에버그린 뱃지 영상", multiple: 3.0, is_short: false, own_match_count: 0, published_at: 2.days.ago, evergreen: true)
    get popular_path(period: "1w")
    assert_response :success
    assert_includes @response.body, "에버그린 뱃지 영상"
    assert_not_includes @response.body, "에버그린 후보"
    assert_not_includes @response.body, "✓ 에버그린"
  end

  # ---- 7.1 검색·필터·정렬 ----

  test "?q 는 제목 부분일치만" do
    make_scored("특별 조사 영상", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago)
    get popular_path(q: "조사")
    assert_response :success
    assert_includes @response.body, "특별 조사 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "?q 특수문자(%,_)는 이스케이프되어 리터럴 매치(인젝션 방어)" do
    make_scored("리터럴 100% 매치", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago)
    make_scored("숫자 1000 영상", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago)
    get popular_path(q: "100%")
    assert_response :success
    assert_includes @response.body, "리터럴 100% 매치"
    assert_not_includes @response.body, "숫자 1000 영상"
  end

  test "?band 는 해당 구독자 밴드 채널만" do
    band1 = Channel.create!(name: "밴드1 채널", category: "한국어교육일반", source: "seed", subscriber_count: 50_000)
    make_scored("밴드1 영상", multiple: 7.0, is_short: false, own_match_count: 0, channel: band1, published_at: 1.day.ago)
    get popular_path(band: "1")
    assert_response :success
    assert_includes @response.body, "밴드1 영상"
    assert_not_includes @response.body, "높은 배수 롱폼" # @channel 은 밴드3(186만)
  end

  test "칼럼 정렬 ?sort=views&dir=desc 는 조회수 내림차순" do
    make_scored("조회수 최상위", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago, view_count: 9_000_000)
    make_scored("조회수 최하위", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago, view_count: 1)
    get popular_path(sort: "views", dir: "desc")
    assert_response :success
    body = @response.body
    assert_operator body.index("조회수 최상위"), :<, body.index("조회수 최하위")
  end

  test "칼럼 정렬 ?sort=views&dir=asc 는 조회수 오름차순(역전)" do
    make_scored("조회수 최상위", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago, view_count: 9_000_000)
    make_scored("조회수 최하위", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.day.ago, view_count: 1)
    get popular_path(sort: "views", dir: "asc")
    assert_response :success
    body = @response.body
    assert_operator body.index("조회수 최하위"), :<, body.index("조회수 최상위")
  end

  test "칼럼 정렬 ?sort=uploaded&dir=desc 는 업로드일 내림차순" do
    make_scored("가장 최신", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 1.hour.ago)
    make_scored("가장 오래된", multiple: 6.0, is_short: false, own_match_count: 0, published_at: 6.days.ago)
    get popular_path(sort: "uploaded", dir: "desc")
    assert_response :success
    body = @response.body
    assert_operator body.index("가장 최신"), :<, body.index("가장 오래된")
  end

  test "정렬 파라미터 없으면 기본 성과 배수 desc" do
    get popular_path
    assert_response :success
    body = @response.body
    assert_operator body.index("높은 배수 롱폼"), :<, body.index("낮은 배수 롱폼")
  end

  test "잘못된 정렬/규모 파라미터는 안전 폴백(200, 기본 정렬)" do
    get popular_path(sort: "xxx", dir: "sideways", band: "9")
    assert_response :success
    assert_includes @response.body, "높은 배수 롱폼"
  end

  test "데이터는 있는데 필터 0건이면 '필터 결과 없음'(콜드스타트 아님)" do
    # setup 에 스코어가 존재 → @has_any_scores true → 필터-empty 문구, "데이터 수집 중" 아님.
    get popular_path(q: "존재하지않는키워드ZZZ")
    assert_response :success
    assert_includes @response.body, "검색·필터 조건에 맞는 급상승 영상이 없습니다."
    assert_not_includes @response.body, "데이터 수집 중", "필터-empty 를 콜드스타트로 오표시하면 안 됨"
  end

  test "스코어가 하나도 없으면 콜드스타트(데이터 수집 중)" do
    VideoScore.delete_all
    get popular_path
    assert_response :success
    assert_includes @response.body, "데이터 수집 중"
  end

  test "검색 폼은 다른 필터(기간·카테고리·유형·규모)를 hidden 으로 보존한다" do
    get popular_path(type: "short", band: "1")
    assert_response :success
    assert_match(/name="type"[^>]*value="short"/, @response.body)
    assert_match(/name="band"[^>]*value="1"/, @response.body)
  end
end
