# 앱 셸(좌측 내비·헤더·활성 강조·인증 게이트)을 검증하는 통합 테스트 (Story 1.4)
require "test_helper"

class AppShellTest < ActionDispatch::IntegrationTest
  NAV_LABELS = ["대시보드", "인기 콘텐츠", "경쟁 채널", "콘텐츠 갭", "저장한 영상", "설정"].freeze
  NAV_PATHS  = ["/", "/popular", "/competitors", "/content-gap", "/saved", "/settings"].freeze

  test "인증 후 root 및 6개 내비 경로가 각각 200" do
    sign_in_as users(:one)
    NAV_PATHS.each do |path|
      get path
      assert_response :success, "#{path} 가 200 이 아님"
    end
  end

  test "대시보드에 6개 내비 라벨이 모두 렌더된다" do
    sign_in_as users(:one)
    get "/"
    NAV_LABELS.each do |label|
      assert_includes @response.body, label, "내비 라벨 '#{label}' 누락"
    end
  end

  test "각 내비 경로에서 해당 항목만 활성(aria-current·primary-600)이다" do
    sign_in_as users(:one)
    NAV_PATHS.each_with_index do |path, i|
      active = NAV_LABELS[i]
      get path
      assert_select "a[data-nav-label='#{active}'][aria-current='page']", 1,
        "#{path} 에서 '#{active}' 가 활성이어야 한다"
      assert_select "a[data-nav-label='#{active}'].bg-primary-600", 1
      (NAV_LABELS - [active]).each do |other|
        assert_select "a[data-nav-label='#{other}'][aria-current='page']", 0,
          "#{path} 에서 '#{other}' 는 비활성이어야 한다"
      end
    end
  end

  test "헤더에 제목·부제·오늘 업데이트·계정 메뉴·채널 추가가 있다" do
    sign_in_as users(:one)
    get "/"
    assert_includes @response.body, "YouTube 콘텐츠 리서치"
    assert_includes @response.body, "다음 주 제작할 주제를 10분 안에 결정하세요"
    assert_includes @response.body, "오늘 업데이트"
    assert_includes @response.body, "로그아웃" # 계정 메뉴에 로그아웃.
    assert_select "summary[aria-label='계정 메뉴']"
    assert_select "a[aria-label='채널 추가']" # + 버튼이 채널 등록으로.
  end

  test "데이터 범위 안내가 내비 하단에 있다" do
    sign_in_as users(:one)
    get "/"
    assert_includes @response.body, "데이터 범위"
    assert_includes @response.body, "YouTube 전체 (한국어 + 일본어 시장)"
  end

  test "미인증 상태에서 모든 앱 경로가 로그인으로 리다이렉트된다" do
    NAV_PATHS.each do |path|
      get path
      assert_redirected_to new_session_path, "#{path} 미인증 리다이렉트 실패"
    end
  end

  test "로그인 화면은 셸(내비/헤더) 없이 렌더된다" do
    get new_session_path
    assert_response :success
    NAV_LABELS.each do |label|
      assert_not_includes @response.body, label, "로그인 화면에 셸 라벨 '#{label}' 이 노출됨"
    end
    assert_select "[data-sidebar-target='panel']", 0
    assert_not_includes @response.body, "YouTube 콘텐츠 리서치"
  end
end
