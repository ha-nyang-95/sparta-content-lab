# 에버그린 후보(경과일 ≥ min_age_days AND 성과 배수 ≥ min_multiple 동시 충족)를 스냅샷 없이 판정·물질화(순수 계산, AD-2)
module Scoring
  class DetermineEvergreen
    def initialize(channel)
      @channel = channel
    end

    def call
      # 튜닝값은 Scoring::Config 로만 읽는다(AD-4, 하드코딩 금지).
      min_age = Scoring::Config.fetch(:evergreen, :min_age_days)
      min_multiple = Scoring::Config.fetch(:evergreen, :min_multiple)
      today = Time.zone.today # Asia/Tokyo 오늘(경과일 경계 규약, 2.x 스냅샷과 동일).

      # 채널의 VideoScore(3.2 산출)를 읽어 후보 여부만 갱신 — 배수·기준선 재계산 없음(AD-11).
      VideoScore.transaction do
        VideoScore.joins(:video).where(videos: { channel_id: @channel.id }).includes(:video).each do |score|
          video = score.video

          # nil 방어(AD-9): 발행일 미상이거나 배수 미계산이면 후보 아님(예외 없음).
          if video.published_at.nil? || score.performance_multiple.nil?
            candidate = false
          else
            # 경과일은 Tokyo 발행일 기준 정수 일수 — UTC datetime 을 Tokyo 날짜로 환산.
            age = (today - video.published_at.in_time_zone.to_date).to_i
            candidate = age >= min_age && score.performance_multiple >= min_multiple
          end

          score.update!(evergreen_candidate: candidate)
        end
      end
    end
  end
end
