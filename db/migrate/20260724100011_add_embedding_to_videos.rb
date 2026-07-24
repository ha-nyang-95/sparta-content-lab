# videos 에 제목 임베딩(packed-float BLOB)과 재생성 판정용 제목 해시 컬럼을 추가한다(AD-10)
class AddEmbeddingToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :embedding, :binary
    add_column :videos, :embedding_source_hash, :string
  end
end
