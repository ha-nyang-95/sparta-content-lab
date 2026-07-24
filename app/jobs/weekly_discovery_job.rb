# 주1회 신규 채널 발굴을 조립만 하는 잡 — 발굴은 DiscoverChannels 위임·Channel(auto) upsert·JobRun 관측(AD-11)
class WeeklyDiscoveryJob < ApplicationJob
  queue_as :default

  # 잡 단위 재시도는 일시적 인프라 오류(DB deadlock)만 — search 쿼터는 경계에서 처리.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

  def perform
    JobRun.reap_stale! # 이전에 중단된 running 실행을 먼저 회수한다.
    run = JobRun.start!("WeeklyDiscoveryJob", retries: executions - 1)

    ledger = Youtube::QuotaLedger.new # search 버킷만 소비(공유 풀 무관).
    added = 0
    failed = 0

    begin
      client = Youtube::Client.new(ledger: ledger)
      candidates = Youtube::DiscoverChannels.new(client: client).call

      candidates.each do |channel_id, info|
        next if Channel.exists?(youtube_channel_id: channel_id) # idempotent — 중복 추가 안 함.

        # 후보별 rescue — 한 후보 추가 실패가 나머지·런 전체를 버리지 않는다(poison-pill 방지).
        Channel.create!(source: "auto", category: info[:category],
                        name: info[:name], youtube_channel_id: channel_id)
        added += 1
      rescue => e
        failed += 1
        Rails.logger.error("[WeeklyDiscoveryJob] 채널 추가 실패(스킵): #{channel_id} — #{e.class}: #{e.message}")
      end

      run.succeed!(quota_used: ledger.spent(:search), channels_processed: added, channels_failed: failed)
    rescue => e
      run.fail!(error: e.message, quota_used: ledger.spent(:search),
                channels_processed: added, channels_failed: failed)
      raise
    end
  end
end
