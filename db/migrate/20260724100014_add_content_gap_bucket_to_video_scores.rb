# 콘텐츠 갭 4구간 버킷(미제작/유사1/유사2+/포화)을 video_scores 에 물질화(4.3, nullable — 경쟁 영상만 설정)
class AddContentGapBucketToVideoScores < ActiveRecord::Migration[8.1]
  def change
    add_column :video_scores, :content_gap_bucket, :string
  end
end
