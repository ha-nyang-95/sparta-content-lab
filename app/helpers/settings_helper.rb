# 설정 화면 표시 헬퍼 — 잡 상태·API 모드 배지, 키 유무·시각 포매팅(§10 토큰만)
module SettingsHelper
  # 잡 상태 → 배지 라벨·클래스(§4.7 정직성, §10 badge/success 토큰). 미지의 값은 중립으로 폴백.
  def job_status_badge(status)
    case status
    when "running"
      { label: "실행 중", klass: "bg-badge-cautionBg text-badge-cautionFg" }
    when "succeeded"
      { label: "성공", klass: "bg-success-50 text-success-700" }
    when "failed"
      { label: "실패", klass: "bg-badge-dangerBg text-badge-dangerFg" }
    else
      { label: status.to_s, klass: "bg-badge-neutralBg text-badge-neutralFg" }
    end
  end

  # API 모드 → 배지. 스텁은 중립으로 명시(진짜인 척 금지), live 는 success.
  def api_mode_badge(mode)
    case mode
    when :live
      { label: "실사용", klass: "bg-success-50 text-success-700" }
    else
      { label: "스텁(개발)", klass: "bg-badge-neutralBg text-badge-neutralFg" }
    end
  end

  # 키 유무만 표기 — 값은 절대 노출하지 않는다(보안).
  def api_key_presence(present)
    present ? "키 있음" : "키 없음"
  end

  # 잡 시각 포매팅 — nil 이면 "—"(AD-9 nil 방어).
  def format_job_time(t)
    t.nil? ? "—" : t.strftime("%Y.%m.%d %H:%M")
  end

  # 잡 오류 문구의 비밀값 마스킹(방어) — live 어댑터가 URL 에 key=<API_KEY> 를 실어, 만약 키 포함 예외가
  # JobRun.error 로 새어들어와도 이 화면에서 노출되지 않게 한다. 오늘은 채널별 rescue 로 도달 불가하나 sink 방어.
  def redact_secrets(text)
    text.to_s.gsub(/([?&](?:key|api_key|token|password)=)[^&\s"']+/i, '\1[REDACTED]')
  end
end
