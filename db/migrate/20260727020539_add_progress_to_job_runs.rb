# 오늘 업데이트 진행 게이지용 — 현재 단계(phase)와 가중 진행률(progress 0~100)을 JobRun 에 기록
class AddProgressToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :phase, :string
    add_column :job_runs, :progress, :integer, default: 0, null: false
  end
end
