# 채널 아바타 이미지 URL(channels.list snippet.thumbnails) — 없으면 nil, 뷰가 이니셜 동그라미로 폴백.
class AddThumbnailUrlToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :thumbnail_url, :string
  end
end
