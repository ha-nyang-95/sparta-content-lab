# 경쟁 영상의 자사 유사영상 개수(N)를 물질화 — content_gap_bucket 과 급상승 행 "N개"가 한 소재지에서 나오게(FR-18 일치, AD-3)
class AddOwnMatchCountToVideoScores < ActiveRecord::Migration[8.1]
  def change
    add_column :video_scores, :own_match_count, :integer
  end
end
