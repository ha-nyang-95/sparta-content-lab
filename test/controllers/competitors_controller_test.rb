# 경쟁 채널 — 200·GET 읽기 전용·경쟁만·구독자 desc nulls last·수동 등록(스텁·중복·파싱)·제외 토글·금지 라벨 부재
require "test_helper"

class CompetitorsControllerTest < ActionDispatch::IntegrationTest
  STUB_ID = "UC1234567890abcdefghijkl" # UC + 22자 — parse_channel_id·스텁 echo 대상

  setup do
    sign_in_as(User.take)
    @competitor = Channel.create!(name: "韓国語の森 with Aki", category: "직접경쟁", source: "seed", is_own: false, subscriber_count: 1_860_000)
  end

  test "GET /competitors 200" do
    get competitors_path
    assert_response :success
  end

  test "읽기 전용 — GET 이 Channel 을 쓰지 않는다" do
    before = Channel.count
    get competitors_path
    assert_equal before, Channel.count
  end

  test "경쟁 채널만 노출하고 자사 채널은 뺀다" do
    Channel.create!(name: "우리자사채널고유이름", category: "직접경쟁", source: "seed", is_own: true, subscriber_count: 500_000)
    get competitors_path
    assert_response :success
    assert_includes @response.body, "韓国語の森 with Aki"
    assert_not_includes @response.body, "우리자사채널고유이름"
  end

  test "구독자수 desc, nil 은 마지막으로 정렬한다" do
    Channel.create!(name: "구독자적음채널", category: "직접경쟁", source: "seed", is_own: false, subscriber_count: 100)
    Channel.create!(name: "구독자미상채널", category: "직접경쟁", source: "seed", is_own: false, subscriber_count: nil)
    get competitors_path
    body = @response.body
    assert_operator body.index("韓国語の森 with Aki"), :<, body.index("구독자적음채널"), "186만이 100보다 위"
    assert_operator body.index("구독자적음채널"), :<, body.index("구독자미상채널"), "nil 이 마지막"
  end

  test "POST create 는 스텁 메타로 source:manual 경쟁 채널을 생성한다" do
    assert_difference "Channel.count", 1 do
      post competitors_path, params: { channel_url: "https://youtube.com/channel/#{STUB_ID}", channel_name: "새 경쟁 채널", category: "직접경쟁" }
    end
    assert_redirected_to competitors_path
    created = Channel.find_by(youtube_channel_id: STUB_ID)
    assert_equal "manual", created.source
    assert_equal false, created.is_own
    assert_equal "새 경쟁 채널", created.name
    assert_not_nil created.subscriber_count, "스텁 statistics.subscriberCount 로 채워짐"
  end

  test "POST create 는 @핸들도 해석해 채널을 생성한다" do
    assert_difference "Channel.count", 1 do
      post competitors_path, params: { channel_url: "@TrilingualTomi", channel_name: "핸들 등록", category: "직접경쟁" }
    end
    assert_redirected_to competitors_path
    created = Channel.find_by(youtube_channel_id: "UC_stub_trilingual_tomi") # 스텁 forHandle 이 반환하는 채널.
    assert_not_nil created, "@핸들로 채널이 생성돼야 한다"
    assert_equal "manual", created.source
  end

  test "POST create 중복 youtube_channel_id 는 생성하지 않고 flash 로 안내한다" do
    Channel.create!(name: "기존 채널", category: "직접경쟁", source: "manual", is_own: false, youtube_channel_id: STUB_ID)
    assert_no_difference "Channel.count" do
      post competitors_path, params: { channel_url: STUB_ID, channel_name: "중복 시도", category: "직접경쟁" }
    end
    assert_redirected_to competitors_path
    assert_equal "이미 등록된 채널입니다.", flash[:alert], "중복은 영문 기본 메시지가 아니라 한국어로"
  end

  test "POST create 잘못된 URL(UC id 없음)은 생성하지 않고 flash 오류" do
    assert_no_difference "Channel.count" do
      post competitors_path, params: { channel_url: "그냥 텍스트", channel_name: "잘못됨", category: "직접경쟁" }
    end
    assert_redirected_to competitors_path
    assert flash[:alert].present?
  end

  test "POST create UC 가 단어 중간(MUCH…)이면 오매칭하지 않고 flash 오류" do
    # 'UC' 가 MUCH 안에 있으나 독립 UC…22 경계가 아니므로 파싱 실패해야 한다(정규식 앞뒤 경계).
    bogus = "MUCH#{'a' * 24}"
    assert_no_difference "Channel.count" do
      post competitors_path, params: { channel_url: bogus, channel_name: "오매칭", category: "직접경쟁" }
    end
    assert_redirected_to competitors_path
    assert flash[:alert].present?
  end

  test "PATCH exclusion 은 excluded 를 토글하고 복원한다" do
    patch competitor_exclusion_path(@competitor)
    assert @competitor.reload.excluded, "제외됨"
    patch competitor_exclusion_path(@competitor)
    assert_not @competitor.reload.excluded, "복원됨"
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get competitors_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end
end
