# 경쟁 채널 — 읽기 전용 index(경쟁 로드/정렬/프리로드, AD-3 재계산 금지) + 수동 등록·제외 토글 쓰기 액션
class CompetitorsController < ApplicationController
  # index 는 GET 읽기 전용 — 계산 없이 필터·정렬·프리로드만. 구독자 증감은 헬퍼가 저장 스냅샷을 읽는다.
  def index
    @active = Channel.competitor.not_excluded
                     .includes(:daily_stats)
                     .order(Arel.sql("subscriber_count DESC NULLS LAST"))
    # 제외 행은 아바타·이름·복원 버튼만 렌더(증감 위젯 없음) — daily_stats 프리로드 불필요.
    @excluded = Channel.competitor.where(excluded: true).order(:name)
  end

  # 수동 등록(쓰기) — 스텁 경계로 메타 조회 후 생성. 중복·유효성·파싱 오류는 flash 로 흡수(500 금지).
  def create
    Youtube::RegisterChannel.new.call(
      url_or_id: params[:channel_url],
      name: params[:channel_name],
      category: params[:category]
    )
    redirect_to competitors_path, notice: "경쟁 채널을 등록했습니다."
  rescue ArgumentError
    redirect_to competitors_path, alert: "채널 URL/ID 를 확인해 주세요."
  rescue ActiveRecord::RecordInvalid => e
    # 중복은 모델 유니크 검증이 먼저 잡으므로(영문 기본 메시지 대신) 한국어로 안내.
    message = if e.record.errors.of_kind?(:youtube_channel_id, :taken)
                "이미 등록된 채널입니다."
              else
                e.record.errors.full_messages.to_sentence
              end
    redirect_to competitors_path, alert: message
  rescue ActiveRecord::RecordNotUnique
    # 검증↔삽입 경합 시의 안전망(정상 경로는 위 RecordInvalid).
    redirect_to competitors_path, alert: "이미 등록된 채널입니다."
  end

  # 제외 토글(쓰기) — excluded 불리언 flip. not_excluded 스코프가 수집·표시·채점에서 자동 제외/복원.
  def toggle_exclusion
    channel = Channel.competitor.find(params[:id])
    channel.update!(excluded: !channel.excluded)
    redirect_to competitors_path, notice: (channel.excluded? ? "채널을 제외했습니다." : "채널을 복원했습니다.")
  rescue ActiveRecord::RecordNotFound
    # 자사 채널·삭제된 id·오래된 링크 — 500/404 대신 친절한 리다이렉트.
    redirect_to competitors_path, alert: "채널을 찾을 수 없습니다."
  end
end
