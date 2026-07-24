# 잡 실행 관측 레코드 — 시작·성공·실패·재시도·쿼터 사용량을 primary DB에 기록(AD-13)
class CreateJobRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :job_runs do |t|
      t.string :job_name, null: false
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error
      t.integer :quota_used
      t.integer :retries, null: false, default: 0

      t.timestamps
    end
  end
end
