# 헤더 실시간 검색(타입어헤드) — 제목 부분일치·5건 상한·total·빈 검색어·제외 채널 배제 검증
require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @ch = Channel.create!(name: "테스트 채널", category: "직접경쟁", source: "seed", is_own: false)
  end

  def make_video(title, channel: @ch)
    channel.videos.create!(youtube_video_id: "v_#{SecureRandom.hex(4)}", title: title, view_count: 100)
  end

  test "GET search 는 제목 부분일치 결과를 JSON 으로 반환한다" do
    make_video("자생법 완전정복")
    make_video("무관한 제목")

    get search_path(q: "자생법")
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal 1, body["total"]
    assert_equal "자생법 완전정복", body["results"].first["title"]
    assert_includes body["results"].first["url"], "youtube.com"
  end

  test "GET search 는 최대 5건만 반환하고 total 은 전체 개수다" do
    7.times { |i| make_video("공통키워드 #{i}") }

    get search_path(q: "공통키워드")
    body = JSON.parse(@response.body)
    assert_equal 7, body["total"]
    assert_equal 5, body["results"].size, "드롭다운은 최대 5건"
  end

  test "빈 검색어는 빈 결과를 반환한다" do
    make_video("아무거나")

    get search_path(q: "")
    body = JSON.parse(@response.body)
    assert_equal 0, body["total"]
    assert_empty body["results"]
  end

  test "제외 채널의 영상은 검색되지 않는다" do
    excluded = Channel.create!(name: "제외채널", category: "직접경쟁", source: "seed", is_own: false, excluded: true)
    make_video("제외키워드 영상", channel: excluded)

    get search_path(q: "제외키워드")
    body = JSON.parse(@response.body)
    assert_equal 0, body["total"], "제외 채널 영상은 검색 제외"
  end
end
