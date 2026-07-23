# 인증 전면 적용·로그인 리다이렉트·회원가입 라우트 부재를 검증하는 통합 테스트
require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "미인증 GET / 는 로그인 화면으로 리다이렉트된다" do
    get "/"
    assert_redirected_to new_session_path
  end

  test "인증된 세션으로 GET / 는 200을 반환한다" do
    sign_in_as users(:one)
    get "/"
    assert_response :success
  end

  test "미인증 상태에서도 로그인 화면은 접근 가능하다(전면 잠금 방지)" do
    get new_session_path
    assert_response :success
  end

  test "공개 회원가입(user 생성) 라우트가 없다" do
    helpers = Rails.application.routes.url_helpers
    refute helpers.respond_to?(:sign_up_path), "sign_up 라우트가 존재하면 안 된다"
    refute helpers.respond_to?(:registration_path), "registration 라우트가 존재하면 안 된다"
    refute helpers.respond_to?(:new_user_registration_path), "new_user_registration 라우트가 존재하면 안 된다"

    # 어떤 라우트도 user 생성/회원가입 컨트롤러로 매핑되지 않는다(헬퍼 이름 추측에 의존하지 않는 강한 검증).
    offending = Rails.application.routes.routes.filter_map { |r| r.defaults[:controller] }.uniq.select do |c|
      c.match?(/(^|\/)(users|registrations|sign_?ups)$/)
    end
    assert_empty offending, "공개 user 생성 컨트롤러 라우트가 없어야 한다: #{offending.inspect}"

    # 흔한 회원가입 경로도 라우팅되지 않는다.
    %w[/sign_up /signup /register /users].each do |path|
      assert_raises(ActionController::RoutingError, "#{path} POST 가 라우팅되면 안 된다") do
        Rails.application.routes.recognize_path(path, method: :post)
      end
    end
  end
end
