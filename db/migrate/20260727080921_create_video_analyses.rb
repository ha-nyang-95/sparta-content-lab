# 영상 기획 분석 캐시 — 자막(스크립트) 기반 Gemini 분석을 영상당 1회 물질화(온디맨드+캐시, 재클릭 즉시)
class CreateVideoAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :video_analyses do |t|
      t.references :video, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "ok" # ok | unavailable
      t.string :detail                              # unavailable 사유(자막 없음 등)
      t.text :intro_excerpt
      t.text :intro_analysis
      t.text :summary
      t.text :overall_analysis
      t.timestamps
    end
  end
end
