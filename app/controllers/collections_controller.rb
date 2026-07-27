# '오늘 업데이트' 수집 트리거 + 진행 상태 조회 — 잡을 큐에 넣기만 하고(AD-11), 게이지는 JobRun 을 폴링해 읽는다
class CollectionsController < ApplicationController
  # 수집 시작 — 이미 running 이면 중복 트리거를 막고, 아니면 DailyCollectionJob 을 enqueue(워커가 백그라운드 실행).
  def create
    if collection_running?
      redirect_back fallback_location: root_path, alert: "이미 수집이 진행 중입니다."
    else
      DailyCollectionJob.perform_later
      redirect_back fallback_location: root_path, notice: "수집을 시작했습니다. 완료까지 몇 분 걸립니다."
    end
  end

  # 게이지 폴링용 상태 JSON — 진행 중 여부·현재 단계·진행률(0~100)·마지막 완료 시각/상태.
  def status
    JobRun.reap_stale! # 중단된 running 을 먼저 회수해 '영원히 진행 중'으로 보이지 않게.
    running = JobRun.where(job_name: "DailyCollectionJob", status: "running").order(:started_at).last
    last_done = JobRun.where(job_name: "DailyCollectionJob", status: %w[succeeded failed])
                      .order(:finished_at).last

    render json: {
      running: running.present?,
      phase: running&.phase,
      progress: running&.progress || 0,
      last_finished_at: last_done&.finished_at&.iso8601,
      last_status: last_done&.status
    }
  end

  private

  def collection_running?
    JobRun.where(job_name: "DailyCollectionJob", status: "running").exists?
  end
end
