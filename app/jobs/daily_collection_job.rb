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
      # Epic 3 스코어링 스테이지 — 스냅샷 뒤 append. 수집과 같은 스코프(youtube_channel_id 있는 채널)만 —
      # 영상 없는 handle-only 채널의 빈 기준선을 만들지 않는다. 채널별 기준선→성과배수→에버그린(이전 산출을 DB에서 읽음, AD-11).
      scoring_attempted = 0
      scoring_failed = 0
      Channel.not_excluded.where.not(youtube_channel_id: nil).find_each do |channel|
        scoring_attempted += 1
        # 세 스테이지를 한 트랜잭션으로 — 중간 실패가 '새 배수 + 옛 에버그린' 같은 불일치 상태를 남기지 않는다(all-or-nothing).
        ApplicationRecord.transaction do
          Scoring::CalculateBaseline.new(channel).call
          Scoring::CalculatePerformance.new(channel).call
          Scoring::DetermineEvergreen.new(channel).call
        end
      rescue => e
        scoring_failed += 1
        Rails.logger.error("[DailyCollectionJob] 채널 스코어링 실패(스킵): #{channel.name} — #{e.class}: #{e.message}")
      end

      # 전 채널 스코어링 실패는 체계적 문제 — 수집 정직성 패턴대로 succeeded 로 위장하지 않고 failed 로 기록한다(finalize 와 동일하게 raise 없이).
      if scoring_attempted.positive? && scoring_failed == scoring_attempted
        run.fail!(error: "전 채널 스코어링 실패(#{scoring_failed}/#{scoring_attempted})",
                  quota_used: ledger.spent(:shared),
                  channels_processed: processed, channels_failed: failed)
      else
        run_similarity_stages # 스코어링 정상 시 Epic 4 전역 스테이지를 에버그린 뒤 append.
        finalize(run, processed, failed, ledger.spent(:shared))
      end
    rescue => e
      # 체계적 실패(스냅샷 단계 raise 등)만 여기 도달 — 채널 실패는 위에서 이미 삼켰다.
      run.fail!(error: e.message, quota_used: ledger.spent(:shared),
                channels_processed: processed, channels_failed: failed)
      raise
    end
  end

  private

  # Epic 4 스테이지 — 전역 배치, 에버그린 뒤. 임베딩→OwnVideoMatch→콘텐츠 갭→주제 클러스터(AD-11). 스테이지별 rescue.
  def run_similarity_stages
    stages = {
      "임베딩" => -> { Embedding::UpsertVectors.new.call },
      "OwnVideoMatch" => -> { Similarity::MatchOwnVideos.new.call },
      "콘텐츠 갭" => -> { Similarity::ClassifyContentGap.new.call },
      "주제 클러스터" => -> { Similarity::BuildTopicClusters.new.call },
    }
    stages.each do |name, stage|
      stage.call
    rescue => e
      Rails.logger.error("[DailyCollectionJob] 유사도 스테이지 실패(스킵): #{name} — #{e.class}: #{e.message}")
    end
  end

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
