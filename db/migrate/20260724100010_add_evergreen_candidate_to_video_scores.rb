# 에버그린 후보(나이 AND 배수 동시 충족) 플래그를 video_scores 에 물질화(3.4, null:false default false)
class AddEvergreenCandidateToVideoScores < ActiveRecord::Migration[8.1]
  def change
    add_column :video_scores, :evergreen_candidate, :boolean, null: false, default: false
  end
end
