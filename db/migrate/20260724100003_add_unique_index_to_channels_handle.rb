# handle 에 부분 유니크 인덱스 — 같은 채널이 handle 로 중복 시드/등록되는 것을 DB 레벨에서 막고
# Story 2.2 의 handle→채널ID 해결이 dedup 앵커로 쓰게 한다. NULL 은 다중 허용(미해결 시드).
class AddUniqueIndexToChannelsHandle < ActiveRecord::Migration[8.1]
  def change
    add_index :channels, :handle, unique: true, where: "handle IS NOT NULL",
              name: "index_channels_on_handle_not_null"
  end
end
