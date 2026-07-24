# 설정 헬퍼 — 잡 상태·API 모드 배지, 키 유무·시각 포매팅 검증(§10 토큰만, 원시 색 부재)
require "test_helper"

class SettingsHelperTest < ActionView::TestCase
  test "job_status_badge running → 실행 중, caution 토큰" do
    b = job_status_badge("running")
    assert_equal "실행 중", b[:label]
    assert_includes b[:klass], "caution"
    assert_no_match(/-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-\d/, b[:klass])
  end

  test "job_status_badge succeeded → 성공, success 토큰" do
    b = job_status_badge("succeeded")
    assert_equal "성공", b[:label]
    assert_includes b[:klass], "success"
    assert_no_match(/-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-\d/, b[:klass])
  end

  test "job_status_badge failed → 실패, danger 토큰" do
    b = job_status_badge("failed")
    assert_equal "실패", b[:label]
    assert_includes b[:klass], "danger"
    assert_no_match(/-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-\d/, b[:klass])
  end

  test "job_status_badge 미지의 상태 → 라벨 그대로, neutral 토큰" do
    b = job_status_badge("weird")
    assert_equal "weird", b[:label]
    assert_includes b[:klass], "neutral"
  end

  test "api_mode_badge :stub → 스텁(개발), neutral" do
    b = api_mode_badge(:stub)
    assert_equal "스텁(개발)", b[:label]
    assert_includes b[:klass], "neutral"
  end

  test "api_mode_badge :live → 실사용, success" do
    b = api_mode_badge(:live)
    assert_equal "실사용", b[:label]
    assert_includes b[:klass], "success"
  end

  test "api_key_presence 유무 문구" do
    assert_equal "키 있음", api_key_presence(true)
    assert_equal "키 없음", api_key_presence(false)
  end

  test "format_job_time nil → 대시, Time → 포맷" do
    assert_equal "—", format_job_time(nil)
    t = Time.zone.local(2026, 7, 25, 9, 5)
    assert_equal "2026.07.25 09:05", format_job_time(t)
  end

  test "redact_secrets 는 URL 쿼리의 키/토큰 값을 마스킹한다" do
    masked = redact_secrets("HTTP 403 https://www.googleapis.com/youtube/v3/channels?id=UC1&key=AIzaSECRET123")
    assert_includes masked, "key=[REDACTED]"
    assert_not_includes masked, "AIzaSECRET123"
    # 일반 오류 문구는 그대로, nil 은 빈 문자열.
    assert_equal "쿼터 초과(quotaExceeded)", redact_secrets("쿼터 초과(quotaExceeded)")
    assert_equal "", redact_secrets(nil)
  end
end
