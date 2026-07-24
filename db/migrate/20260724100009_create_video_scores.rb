# 영상별 성과 배수·순위 적격·검증 요망 플래그를 물질화하는 video_scores 테이블 생성 — video 1:1 유니크(AD-3/AD-5)
class CreateVideoScores < ActiveRecord::Migration[8.1]
  def change
    create_table :video_scores do |t|
      t.references :video, null: false, foreign_key: true, index: { unique: true }
      t.float :performance_multiple
      t.boolean :rank_eligible, null: false, default: false
      t.boolean :needs_verification, null: false, default: false

      t.timestamps
    end
  end
end
