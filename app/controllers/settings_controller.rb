# 설정 화면 — 수집 상태·API 연결·데이터 범위/백업·계정을 읽기 전용으로 로드(AD-3)
class SettingsController < ApplicationController
  def index
    # 최근 잡 실행 이력(최신순 20) — 조회·정렬만, 쓰기/계산 없음.
    @job_runs = JobRun.order(created_at: :desc).limit(20)
    # 데이터 신선도 = 마지막 성공 DailyCollectionJob 의 종료 시각.
    @last_success = JobRun.where(job_name: "DailyCollectionJob", status: "succeeded").order(finished_at: :desc).first
    # 임베딩 빌링 소진 경보 — 가장 최근 DailyCollectionJob 이 크레딧 소진(QuotaExhausted)으로 실패했으면 배너 노출.
    latest = JobRun.where(job_name: "DailyCollectionJob").order(created_at: :desc).first
    @billing_alert = latest if latest&.status == "failed" && latest.error.to_s.include?("크레딧")
    # 추적 채널 수(전체/경쟁/자사).
    @channel_counts = { total: Channel.count, competitor: Channel.competitor.count, own: Channel.own.count }
    # API 상태 — 경계의 mode·키 유무만(값 노출 금지, AD-1). 키 유무는 경계 술어로 읽는다.
    @youtube = { mode: Youtube::Config.mode, key: Youtube::Config.key_present? }
    @embedding = { mode: Embedding::Config.mode, key: Embedding::Config.key_present? }
    # 최신 백업 시각(AD-17: storage/backups) — app-*.sqlite3 중 mtime 최신(파일명 사전순 아님).
    # 읽기 불가·소실 파일은 건너뛰고, 하나도 없으면 nil. 뷰에서 파일시스템 접근하지 않는다(예외 격리).
    @backup_latest_at = latest_backup_mtime
    # 로그인 사용자(nil 방어는 뷰에서).
    @current_user = Current.user
  end

  private

  # storage/backups 의 app-*.sqlite3 파일 중 가장 최신 mtime(Time) 또는 nil.
  # 파일별 File.mtime 예외(EACCES/ENOENT 등)는 그 파일만 건너뛴다 — 상태 페이지가 500 나지 않게.
  def latest_backup_mtime
    Dir.glob(Rails.root.join("storage", "backups", "app-*.sqlite3").to_s)
       .filter_map { |f| File.mtime(f) rescue nil }
       .max
  end
end
