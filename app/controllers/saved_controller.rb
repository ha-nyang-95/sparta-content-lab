# 저장한 영상 화면 — 현재 사용자의 저장 영상을 물질화 값으로 프리로드해 §4.3 표로 재열람(읽기 전용, AD-3)
class SavedController < ApplicationController
  def index
    # 기본 최근 저장순, 표 칼럼 헤더로 정렬 변경(SortableHelper). 정렬용 videos·video_scores 조인 + N+1 preload 분리.
    scope = Current.user.saved_videos.left_joins(video: :video_score)
                   .preload(video: [:channel, :daily_stats, :video_score])
    @saved = helpers.apply_video_sort(scope, params, "saved_videos.created_at DESC").to_a
    @saved_ids = @saved.map(&:video_id).to_set
  end
end
