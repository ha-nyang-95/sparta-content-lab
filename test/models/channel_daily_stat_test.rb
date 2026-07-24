# ChannelDailyStat 검증·연관·(channel_id,date) 유니크를 검증
require "test_helper"

class ChannelDailyStatTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "구독자 채널", category: "직접경쟁", source: "seed")
  end

  test "유효한 스냅샷은 저장된다" do
    stat = @channel.daily_stats.new(date: Date.new(2026, 7, 24), subscriber_count: 5000)
    assert stat.valid?, stat.errors.full_messages.to_sentence
    assert stat.save
  end

  test "subscriber_count 는 nil 이어도 유효하다" do
    stat = @channel.daily_stats.new(date: Date.new(2026, 7, 24), subscriber_count: nil)
    assert stat.valid?, stat.errors.full_messages.to_sentence
  end

  test "date 는 필수다" do
    stat = @channel.daily_stats.new(date: nil, subscriber_count: 1)
    assert_not stat.valid?
    assert stat.errors[:date].any?
  end

  test "belongs_to :channel — channel 없이는 무효다" do
    stat = ChannelDailyStat.new(date: Date.new(2026, 7, 24), subscriber_count: 1)
    assert_not stat.valid?
    assert stat.errors[:channel].any?
  end

  test "(channel_id,date) 는 유니크 — 같은 날 두 번째 행은 무효다" do
    @channel.daily_stats.create!(date: Date.new(2026, 7, 24), subscriber_count: 5000)
    dup = @channel.daily_stats.new(date: Date.new(2026, 7, 24), subscriber_count: 5100)
    assert_not dup.valid?
    assert dup.errors[:channel_id].any?
  end

  test "유니크 위반은 DB 인덱스에서도 raise 된다" do
    @channel.daily_stats.create!(date: Date.new(2026, 7, 24), subscriber_count: 5000)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ChannelDailyStat.new(channel_id: @channel.id, date: Date.new(2026, 7, 24), subscriber_count: 5100).save!(validate: false)
    end
  end
end
