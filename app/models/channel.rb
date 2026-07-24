# 추적 대상 유튜브 채널 — 4분류·source 검증, excluded 제외 스코프, 영상 has_many
class Channel < ApplicationRecord
  CATEGORIES = %w[직접경쟁 한국어교육일반 언어교육참고 상단퍼널].freeze
  SOURCES = %w[seed auto manual].freeze

  has_many :videos, dependent: :destroy
  has_many :daily_stats, class_name: "ChannelDailyStat", dependent: :destroy

  # 빈 문자열은 nil 로 정규화한다 — "" 는 유니크 인덱스에서 NULL 이 아니라 충돌하므로(AD-9 nil 방어 정합).
  normalizes :youtube_channel_id, with: ->(v) { v.presence }
  normalizes :handle, with: ->(v) { v.presence }

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :source, inclusion: { in: SOURCES }
  validates :excluded, inclusion: { in: [true, false] }
  validates :youtube_channel_id, uniqueness: true, allow_nil: true
  validates :handle, uniqueness: true, allow_nil: true

  # excluded 채널은 이후 수집·표시에서 제외한다
  scope :not_excluded, -> { where(excluded: false) }
end
