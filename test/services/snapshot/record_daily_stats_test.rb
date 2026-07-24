# Snapshot::RecordDailyStats — 저장·nil 스킵·idempotent·Asia/Tokyo 날짜 경계를 검증
require "test_helper"

class Snapshot::RecordDailyStatsTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "수집 채널", category: "직접경쟁", source: "seed", subscriber_count: 5000)
    @video = @channel.videos.create!(youtube_video_id: "vid_rec_1", title: "공개", view_count: 1234)
    @hidden = @channel.videos.create!(youtube_video_id: "vid_rec_hidden", title: "회원 전용", view_count: nil)
  end

  test "view_count 있는 영상은 오늘 스냅샷이 값과 함께 생성된다" do
    Snapshot::RecordDailyStats.call
    stat = VideoDailyStat.find_by(video_id: @video.id, date: Time.zone.today)
    assert_not_nil stat
    assert_equal 1234, stat.view_count
  end

  test "view_count 가 nil 인 영상은 스냅샷을 만들지 않는다(스킵)" do
    Snapshot::RecordDailyStats.call
    assert_nil VideoDailyStat.find_by(video_id: @hidden.id)
    assert_equal 0, VideoDailyStat.where(video_id: @hidden.id).count
  end

  test "subscriber_count 있는 채널은 스냅샷이 생성된다" do
    Snapshot::RecordDailyStats.call
    stat = ChannelDailyStat.find_by(channel_id: @channel.id, date: Time.zone.today)
    assert_not_nil stat
    assert_equal 5000, stat.subscriber_count
  end

  test "subscriber_count 가 nil 인 채널은 스냅샷을 만들지 않는다(스킵)" do
    hidden_channel = Channel.create!(name: "구독자 숨김", category: "직접경쟁", source: "seed", subscriber_count: nil)
    Snapshot::RecordDailyStats.call
    assert_nil ChannelDailyStat.find_by(channel_id: hidden_channel.id)
  end

  test "같은 날 재실행은 중복 행을 만들지 않고 값을 갱신한다(idempotent)" do
    Snapshot::RecordDailyStats.call
    assert_equal 1, VideoDailyStat.where(video_id: @video.id).count

    @video.update!(view_count: 9999)
    Snapshot::RecordDailyStats.call

    assert_equal 1, VideoDailyStat.where(video_id: @video.id).count
    assert_equal 9999, VideoDailyStat.find_by(video_id: @video.id, date: Time.zone.today).view_count
  end

  test "요약 카운트를 반환한다" do
    result = Snapshot::RecordDailyStats.call
    assert_equal 1, result[:videos_recorded]
    assert_equal 1, result[:channels_recorded]
    assert_equal Time.zone.today, result[:date]
  end

  test "excluded 채널의 영상·구독자는 스냅샷하지 않는다(수집 제외)" do
    excluded = Channel.create!(name: "제외 채널", category: "직접경쟁", source: "manual",
                               excluded: true, subscriber_count: 9999)
    excluded.videos.create!(youtube_video_id: "vid_excl", title: "제외 영상", view_count: 777)

    Snapshot::RecordDailyStats.call

    assert_equal 0, VideoDailyStat.joins(:video).where(videos: { channel_id: excluded.id }).count
    assert_equal 0, ChannelDailyStat.where(channel_id: excluded.id).count
    # 비-excluded 채널은 정상 스냅샷
    assert_operator VideoDailyStat.count, :>=, 1
  end

  test "날짜 경계는 Asia/Tokyo — UTC 15:00 은 Tokyo 익일로 스냅샷된다" do
    assert_equal "Asia/Tokyo", Time.zone.name
    # UTC 2026-07-24 15:00 == Tokyo 2026-07-25 00:00 (UTC+9)
    travel_to Time.utc(2026, 7, 24, 15, 0, 0) do
      assert_equal Date.new(2026, 7, 25), Time.zone.today
      Snapshot::RecordDailyStats.call
      stat = VideoDailyStat.find_by(video_id: @video.id)
      assert_equal Date.new(2026, 7, 25), stat.date
    end
  end
end
