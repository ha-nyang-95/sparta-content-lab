# 잡 실행 관측 레코드 — 시작·성공·실패·재시도·쿼터 사용량·채널 처리/실패 수를 기록(AD-13)
class JobRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  validates :job_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  # 잡 실행 시작 — running 상태로 started_at·이번 시도의 재시도 횟수를 찍어 생성한다.
  def self.start!(job_name, retries: 0)
    create!(job_name: job_name, status: "running", started_at: Time.current, retries: retries)
  end

  # 프로세스 중단(kill/deploy/OOM)으로 running 에 멈춘 오래된 실행을 failed 로 회수한다(고아 방지).
  def self.reap_stale!(older_than: 6.hours)
    where(status: "running").where(started_at: ..older_than.ago)
      .update_all(status: "failed", finished_at: Time.current,
                  error: "stale — 프로세스 중단 추정(reaped)", updated_at: Time.current)
  end

  # 성공 종료 — finished_at·쿼터 사용량·채널 처리/실패 수를 기록하고 succeeded 로 전이한다.
  def succeed!(quota_used: nil, channels_processed: 0, channels_failed: 0)
    update!(status: "succeeded", finished_at: Time.current, quota_used: quota_used,
            channels_processed: channels_processed, channels_failed: channels_failed)
  end

  # 실패 종료 — finished_at·에러·쿼터·채널 수를 기록하고 failed 로 전이한다.
  def fail!(error:, quota_used: nil, channels_processed: 0, channels_failed: 0)
    update!(status: "failed", finished_at: Time.current, error: error, quota_used: quota_used,
            channels_processed: channels_processed, channels_failed: channels_failed)
  end
end
