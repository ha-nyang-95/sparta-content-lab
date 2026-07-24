# 사용자가 저장(북마크)한 영상 — (user, video) 유니크(AD-14)
class SavedVideo < ApplicationRecord
  belongs_to :user
  belongs_to :video

  validates :video_id, uniqueness: { scope: :user_id }
end
