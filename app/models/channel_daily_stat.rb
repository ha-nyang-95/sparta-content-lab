# 채널 구독자 수의 일별 스냅샷 — (channel_id,date) 유니크로 하루 중복을 막는다(AD-5)
class ChannelDailyStat < ApplicationRecord
  belongs_to :channel

  validates :date, presence: true
  validates :channel_id, uniqueness: { scope: :date }
end
