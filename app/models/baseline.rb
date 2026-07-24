# 채널·유형별 중앙값 기준선 물질화 대상 — 유형별 1행(쇼츠/롱폼 절대 미공유, AD-8)
class Baseline < ApplicationRecord
  belongs_to :channel

  VIDEO_TYPES = %w[short long].freeze

  validates :video_type, inclusion: { in: VIDEO_TYPES }
  validates :video_type, uniqueness: { scope: :channel_id }
  validates :sample_size, numericality: { greater_than_or_equal_to: 0 }
end
