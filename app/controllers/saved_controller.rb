# 저장한 영상 화면 — 현재 사용자의 저장 영상을 물질화 값으로 프리로드해 §4.3 표로 재열람(읽기 전용, AD-3)
class SavedController < ApplicationController
  def index
    @saved = Current.user.saved_videos
                    .includes(video: [:channel, :daily_stats, :video_score])
                    .order(created_at: :desc)
    @saved_ids = @saved.map(&:video_id).to_set
  end
end
