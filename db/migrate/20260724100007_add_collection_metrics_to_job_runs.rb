# JobRun 에 채널 처리/실패 수·조회 인덱스 추가 — 부분·전채널 실패를 정직하게 관측하기 위함(AD-13)
class AddCollectionMetricsToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :channels_processed, :integer, null: false, default: 0
    add_column :job_runs, :channels_failed, :integer, null: false, default: 0
    add_index :job_runs, [:job_name, :created_at]
  end
end
