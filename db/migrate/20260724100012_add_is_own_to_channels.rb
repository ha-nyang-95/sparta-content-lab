# channels 에 자사/경쟁 파티션 플래그(is_own)를 추가한다 — own=자사 채널(운영자 결정, 4.2)
class AddIsOwnToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :is_own, :boolean, null: false, default: false
  end
end
