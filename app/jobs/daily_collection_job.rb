# 일일 수집 파이프라인 체인을 조립만 하는 잡 — 로직은 서비스에 위임(AD-11)·JobRun 관측·쿼터 공유
class DailyCollectionJob < ApplicationJob
  queue_as :default

  # 잡 단위 재시도는 일시적 인프라 오류(DB deadlock)만 — 지수 백오프, 별도 실행이라 하루 1회 상한과 무관.
  # YouTube rate/quota 는 경계(2.2 백오프)·채널별 rescue 에서 처리하므로 잡 재시도 대상이 아니다.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

  def perform
    JobRun.reap_stale! # 이전에 중단된 running 실행을 먼저 회수한다.
    run = JobRun.start!("DailyCollectionJob", retries: executions - 1)

    ledger = Youtube::QuotaLedger.new # 하나의 원장을 전 채널이 공유해 런 전체 쿼터를 누적 회계.
    processed = 0
    failed = 0

    begin
      client = Youtube::Client.new(ledger: ledger)
      Channel.not_excluded.where.not(youtube_channel_id: nil).find_each do |channel|
        # 채널별 rescue — 한 채널 실패가 앞 채널 결과나 런 전체를 버리지 않는다(부분 진행 보존).
        Youtube::FetchChannelVideos.new(client: client).call(channel)
        processed += 1
      rescue => e
        failed += 1
        Rails.logger.error("[DailyCollectionJob] 채널 수집 실패(스킵): #{channel.name} — #{e.class}: #{e.message}")
      end

      Snapshot::RecordDailyStats.call
      # Epic 3 스테이지(기준선→성과배수→에버그린 후보)는 여기 스냅샷 뒤에 append된다(자리).

      finalize(run, processed, failed, ledger.spent(:shared))
    rescue => e
      # 체계적 실패(스냅샷 단계 raise 등)만 여기 도달 — 채널 실패는 위에서 이미 삼켰다.
      run.fail!(error: e.message, quota_used: ledger.spent(:shared),
                channels_processed: processed, channels_failed: failed)
      raise
    end
  end

  private

  # 전 채널이 실패하면 체계적 문제로 보고 succeeded 로 위장하지 않는다(정직성). 부분 실패는 succeeded + 실패 수 기록.
  def finalize(run, processed, failed, quota_used)
    total = processed + failed
    if total.positive? && processed.zero?
      run.fail!(error: "전 채널 수집 실패(#{failed}/#{total})", quota_used: quota_used,
                channels_processed: processed, channels_failed: failed)
    else
      run.succeed!(quota_used: quota_used, channels_processed: processed, channels_failed: failed)
    end
  end
end
