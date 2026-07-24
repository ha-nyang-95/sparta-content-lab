# 경쟁 채널 — 읽기 전용 index(경쟁 로드/정렬/프리로드, AD-3 재계산 금지) + 수동 등록·제외 토글 쓰기 액션
class CompetitorsController < ApplicationController
  # index 는 GET 읽기 전용 — 계산 없이 필터·정렬·프리로드만. 구독자 증감은 헬퍼가 저장 스냅샷을 읽는다.
  def index
    @active = Channel.competitor.not_excluded
                     .includes(:daily_stats)
                     .order(Arel.sql("subscriber_count DESC NULLS LAST"))
    @excluded = Channel.competitor.where(excluded: true)
                       .includes(:daily_stats)
                       .order(:name)
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
    redirect_to competitors_path, alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to competitors_path, alert: "이미 등록된 채널입니다."
  end

  # 제외 토글(쓰기) — excluded 불리언 flip. not_excluded 스코프가 수집·표시·채점에서 자동 제외/복원.
  def toggle_exclusion
    channel = Channel.competitor.find(params[:id])
    channel.update!(excluded: !channel.excluded)
    redirect_to competitors_path, notice: (channel.excluded? ? "채널을 제외했습니다." : "채널을 복원했습니다.")
  end
end
