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
      # 게이지 단계 경계 — 수집 0~25, 스코어링 25~35, 임베딩 35~85, 분석 85~100(가중 진행률).
      total_channels = Channel.not_excluded.where.not(youtube_channel_id: nil).count
      run.mark_progress!(phase: "채널 수집", progress: 0)
      Channel.not_excluded.where.not(youtube_channel_id: nil).find_each do |channel|
        # 채널별 rescue — 한 채널 실패가 앞 채널 결과나 런 전체를 버리지 않는다(부분 진행 보존).
        Youtube::FetchChannelVideos.new(client: client).call(channel)
        processed += 1
      rescue => e
        failed += 1
        Rails.logger.error("[DailyCollectionJob] 채널 수집 실패(스킵): #{channel.name} — #{e.class}: #{e.message}")
      ensure
        run.mark_progress!(phase: "채널 수집",
                           progress: total_channels.zero? ? 25 : (processed + failed).to_f / total_channels * 25)
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
      ensure
        run.mark_progress!(phase: "스코어링",
                           progress: 25 + (total_channels.zero? ? 10 : scoring_attempted.to_f / total_channels * 10))
      end

      # 전 채널 스코어링 실패는 체계적 문제 — 수집 정직성 패턴대로 succeeded 로 위장하지 않고 failed 로 기록한다(finalize 와 동일하게 raise 없이).
      if scoring_attempted.positive? && scoring_failed == scoring_attempted
        run.fail!(error: "전 채널 스코어링 실패(#{scoring_failed}/#{scoring_attempted})",
                  quota_used: ledger.spent(:shared),
                  channels_processed: processed, channels_failed: failed)
      else
        # 유사도 스테이지 실행 — 임베딩 크레딧 소진(빌링)이면 메시지를 돌려받아 런을 failed 로 정직하게 기록한다.
        billing_error = run_similarity_stages(run)
        if billing_error
          run.fail!(error: billing_error, quota_used: ledger.spent(:shared),
                    channels_processed: processed, channels_failed: failed)
        else
          finalize(run, processed, failed, ledger.spent(:shared))
        end
      end
    rescue => e
      # 체계적 실패(스냅샷 단계 raise 등)만 여기 도달 — 채널 실패는 위에서 이미 삼켰다.
      run.fail!(error: e.message, quota_used: ledger.spent(:shared),
                channels_processed: processed, channels_failed: failed)
      raise
    end
  end

  private

  # Epic 4 유사도 + Epic 5 추천 스테이지 — 전역 배치, 에버그린 뒤. 임베딩→OwnVideoMatch→콘텐츠 갭→주제 클러스터→기회 점수→추천(AD-11). 스테이지별 rescue.
  # 임베딩은 가장 길어 영상별 하위 진행(35→85)을 콜백으로 받고, 나머지 5스테이지는 분석(85→100)으로 스테이지 경계마다 마크.
  # 임베딩 크레딧 소진(빌링) 시 그 메시지를 반환한다(그 외엔 nil). 호출부가 런을 failed 로 기록하는 신호.
  def run_similarity_stages(run)
    billing_error = nil
    run.mark_progress!(phase: "임베딩", progress: 35)
    begin
      Embedding::UpsertVectors.new.call(progress: lambda do |done, total|
        run.mark_progress!(phase: "임베딩", progress: 35 + (total.zero? ? 50 : done.to_f / total * 50))
      end)
    rescue Embedding::QuotaExhausted => e
      billing_error = e.message # 빌링 소진 — 아래 스테이지는 기존 임베딩으로 진행하되 런은 failed 로 기록.
      Rails.logger.error("[DailyCollectionJob] 임베딩 크레딧 소진 — #{e.message}")
    rescue => e
      Rails.logger.error("[DailyCollectionJob] 유사도 스테이지 실패(스킵): 임베딩 — #{e.class}: #{e.message}")
    end

    analyze_stages = {
      "OwnVideoMatch" => -> { Similarity::MatchOwnVideos.new.call },
      "콘텐츠 갭" => -> { Similarity::ClassifyContentGap.new.call },
      "주제 클러스터" => -> { Similarity::BuildTopicClusters.new.call },
      "기회 점수" => -> { Scoring::CalculateOpportunityScore.new.call },
      "추천" => -> { Scoring::GenerateRecommendations.new.call },
    }
    analyze_stages.each_with_index do |(name, stage), i|
      run.mark_progress!(phase: "분석: #{name}", progress: 85 + i.to_f / analyze_stages.size * 15)
      stage.call
    rescue => e
      Rails.logger.error("[DailyCollectionJob] 유사도 스테이지 실패(스킵): #{name} — #{e.class}: #{e.message}")
    end

    billing_error
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
