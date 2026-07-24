# 설정 화면 — 200·읽기 전용·잡 이력/신선도·상태 배지·API 모드/키 유무·키 값 미노출·로그아웃·금지 라벨 검증
require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
  end

  test "GET /settings 200" do
    get settings_path
    assert_response :success
  end

  test "읽기 전용 — GET 이 JobRun 을 쓰지 않는다" do
    before = JobRun.count
    get settings_path
    assert_equal before, JobRun.count
  end

  test "성공 JobRun 이 있으면 잡 이름·성공 배지·신선도가 보인다" do
    JobRun.create!(job_name: "DailyCollectionJob", status: "succeeded",
                   started_at: 2.hours.ago, finished_at: 1.hour.ago,
                   channels_processed: 12, channels_failed: 0, retries: 0, quota_used: 4200)
    get settings_path
    assert_response :success
    assert_includes @response.body, "DailyCollectionJob"
    assert_includes @response.body, "성공"
    assert_includes @response.body, "마지막 성공 수집"
  end

  test "실패 JobRun 은 danger 배지와 오류 텍스트를 숨기지 않고 보여준다" do
    JobRun.create!(job_name: "DailyCollectionJob", status: "failed",
                   started_at: 2.hours.ago, finished_at: 1.hour.ago,
                   channels_processed: 3, channels_failed: 9, retries: 2, error: "쿼터 초과")
    get settings_path
    assert_response :success
    assert_includes @response.body, "실패"
    assert_includes @response.body, "쿼터 초과"
  end

  test "잡 오류에 API 키가 섞여도 화면엔 마스킹돼 보인다(sink 방어)" do
    JobRun.create!(job_name: "DailyCollectionJob", status: "failed",
                   started_at: 2.hours.ago, finished_at: 1.hour.ago,
                   error: "HTTP 403 https://www.googleapis.com/youtube/v3/channels?id=UC1&key=AIzaLEAKED9999")
    get settings_path
    assert_response :success
    assert_not_includes @response.body, "AIzaLEAKED9999", "키 값이 오류 문구로 새면 안 됨"
    assert_includes @response.body, "[REDACTED]"
  end

  test "JobRun 이 없으면 empty 상태를 표시한다" do
    JobRun.delete_all
    get settings_path
    assert_response :success
    assert_includes @response.body, "수집 이력 없음"
    assert_includes @response.body, "아직 수집 실행이 없습니다."
  end

  test "API 섹션 — test 환경은 stub 강제, 모드 배지 텍스트가 보인다" do
    get settings_path
    assert_response :success
    assert_equal :stub, Youtube::Config.mode
    assert_includes @response.body, "스텁(개발)"
  end

  test "키 유무 표기 + 키 값 자체는 노출되지 않는다" do
    get settings_path
    assert_response :success
    yt_key = Youtube::Config.api_key
    if yt_key.present?
      assert_includes @response.body, "키 있음"
      assert_not_includes @response.body, yt_key
    else
      assert_includes @response.body, "키 없음"
    end
  end

  test "로그아웃 링크(DELETE session_path)가 있다" do
    get settings_path
    assert_response :success
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[name=_method][value=delete]", 1
    end
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get settings_path
    assert_response :success
    assert_not_includes @response.body, "구독자 대비 조회수"
  end
end
