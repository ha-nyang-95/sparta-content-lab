# 경쟁 영상↔자사 영상 임베딩 유사 매칭(τ 이상)을 배치로 물질화하는 테이블(FR-17, 4.2)
class CreateOwnVideoMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :own_video_matches do |t|
      t.references :competitor_video, null: false, foreign_key: { to_table: :videos }
      t.references :own_video, null: false, foreign_key: { to_table: :videos }
      t.float :similarity, null: false

      t.timestamps
    end
    add_index :own_video_matches, [:competitor_video_id, :own_video_id], unique: true
  end
end
