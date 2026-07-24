# 오늘(Asia/Tokyo) 조회수·구독자를 일별 스냅샷으로 원자 upsert 기록한다(excluded 제외·nil 스킵)
module Snapshot
  class RecordDailyStats
    # date(기본 Tokyo 오늘) 스냅샷. upsert_all 로 (owner,date) 유니크에 원자 upsert —
    # 같은 날 재실행은 값 갱신(중복 없음), 동시 실행에도 RecordNotUnique 로 체인을 끊지 않는다.
    def self.call(date: Time.zone.today)
      video_rows = Video.joins(:channel)
                        .where(channels: { excluded: false }) # excluded 채널은 수집 제외(AD, project-context §5)
                        .where.not(view_count: nil)           # nil(회원전용)은 데이터 포인트 없음 — 스킵
                        .pluck(:id, :view_count)
                        .map { |video_id, view_count| { video_id: video_id, date: date, view_count: view_count } }
      VideoDailyStat.upsert_all(video_rows, unique_by: %i[video_id date]) if video_rows.any?

      channel_rows = Channel.not_excluded
                            .where.not(subscriber_count: nil) # 구독자 숨김은 스킵
                            .pluck(:id, :subscriber_count)
                            .map { |channel_id, subscriber_count| { channel_id: channel_id, date: date, subscriber_count: subscriber_count } }
      ChannelDailyStat.upsert_all(channel_rows, unique_by: %i[channel_id date]) if channel_rows.any?

      { date: date, videos_recorded: video_rows.size, channels_recorded: channel_rows.size }
    end
  end
end
