# VideoDailyStat 검증·연관·(video_id,date) 유니크를 검증
require "test_helper"

class VideoDailyStatTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "스냅샷 채널", category: "직접경쟁", source: "seed")
    @video = @channel.videos.create!(youtube_video_id: "vid_stat_1", title: "제목")
  end

  test "유효한 스냅샷은 저장된다" do
    stat = @video.daily_stats.new(date: Date.new(2026, 7, 24), view_count: 1234)
    assert stat.valid?, stat.errors.full_messages.to_sentence
    assert stat.save
  end

  test "view_count 는 nil 이어도 유효하다" do
    stat = @video.daily_stats.new(date: Date.new(2026, 7, 24), view_count: nil)
    assert stat.valid?, stat.errors.full_messages.to_sentence
  end

  test "date 는 필수다" do
    stat = @video.daily_stats.new(date: nil, view_count: 1)
    assert_not stat.valid?
    assert stat.errors[:date].any?
  end

  test "belongs_to :video — video 없이는 무효다" do
    stat = VideoDailyStat.new(date: Date.new(2026, 7, 24), view_count: 1)
    assert_not stat.valid?
    assert stat.errors[:video].any?
  end

  test "(video_id,date) 는 유니크 — 같은 날 두 번째 행은 무효다" do
    @video.daily_stats.create!(date: Date.new(2026, 7, 24), view_count: 1234)
    dup = @video.daily_stats.new(date: Date.new(2026, 7, 24), view_count: 5678)
    assert_not dup.valid?
    assert dup.errors[:video_id].any?
  end

  test "유니크 위반은 DB 인덱스에서도 raise 된다" do
    @video.daily_stats.create!(date: Date.new(2026, 7, 24), view_count: 1234)
    assert_raises(ActiveRecord::RecordNotUnique) do
      # 검증을 우회해 DB 유니크 인덱스가 직접 막는지 확인
      VideoDailyStat.new(video_id: @video.id, date: Date.new(2026, 7, 24), view_count: 5678).save!(validate: false)
    end
  end
end
