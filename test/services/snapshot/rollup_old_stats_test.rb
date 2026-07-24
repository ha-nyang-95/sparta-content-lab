# Snapshot::RollupOldStats — 90일 이후 주단위 씨닝(주당 최신 1개), 최근 90일 보존을 검증
require "test_helper"

class Snapshot::RollupOldStatsTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "롤업 채널", category: "직접경쟁", source: "seed")
    @video = @channel.videos.create!(youtube_video_id: "vid_roll_1", title: "제목")
    @today = Date.new(2026, 7, 24)
    # today-100 .. today 연속 101일치 일별 스냅샷
    (0..100).each do |ago|
      d = @today - ago
      @video.daily_stats.create!(date: d, view_count: 1000 + (100 - ago))
    end
  end

  test "90일 이후 행은 ISO주당 최신 1개만 남고, 최근 90일 행은 모두 보존된다" do
    cutoff = @today - 90 # 2026-04-25
    old_dates = (0..100).map { |ago| @today - ago }.select { |d| d < cutoff }
    recent_count = VideoDailyStat.where("date >= ?", cutoff).count

    Snapshot::RollupOldStats.call(today: @today)

    # 최근 90일(>= cutoff)은 손대지 않는다
    assert_equal recent_count, VideoDailyStat.where("date >= ?", cutoff).count

    # 90일 이전은 ISO주당 1개로 씨닝 — 기대치는 old_dates 의 고유 ISO주 수
    expected_old_weeks = old_dates.map { |d| d.strftime("%G-%V") }.uniq.count
    assert_equal expected_old_weeks, VideoDailyStat.where("date < ?", cutoff).count
  end

  test "각 남은 주는 그 주의 최대 date 행이다" do
    Snapshot::RollupOldStats.call(today: @today)
    cutoff = @today - 90

    remaining = VideoDailyStat.where("date < ?", cutoff).to_a
    remaining.group_by { |r| r.date.strftime("%G-%V") }.each_value do |group|
      assert_equal 1, group.size, "주당 1개만 남아야 한다"
    end

    # 구체 검증: 특정 주(예: cutoff 직전 주)의 남은 행이 max date 인지.
    # 원래 그 주에 있었을 날짜들 중 실제 남은 것이 최대인지 재구성.
    old_all = (0..100).map { |ago| @today - ago }.select { |d| d < cutoff }
    by_week = old_all.group_by { |d| d.strftime("%G-%V") }
    by_week.each do |week, dates|
      kept = remaining.find { |r| r.date.strftime("%G-%V") == week }
      assert_not_nil kept, "주 #{week} 의 대표 행이 있어야 한다"
      assert_equal dates.max, kept.date, "주 #{week} 는 최대 date 가 남아야 한다"
    end
  end

  test "삭제된 총 행 수를 반환한다" do
    before = VideoDailyStat.count
    deleted = Snapshot::RollupOldStats.call(today: @today)
    after = VideoDailyStat.count
    assert_equal before - after, deleted
    assert deleted > 0
  end

  test "채널 스냅샷도 동일하게 씨닝된다" do
    (0..100).each do |ago|
      @channel.daily_stats.create!(date: @today - ago, subscriber_count: 5000 + ago)
    end
    cutoff = @today - 90
    old_dates = (0..100).map { |ago| @today - ago }.select { |d| d < cutoff }
    expected_old_weeks = old_dates.map { |d| d.strftime("%G-%V") }.uniq.count

    Snapshot::RollupOldStats.call(today: @today)

    assert_equal expected_old_weeks, ChannelDailyStat.where("date < ?", cutoff).count
  end

  test "여러 영상의 오래된 스냅샷이 소유자별로 격리 씨닝된다" do
    today = Time.zone.today
    ch = Channel.create!(name: "다소유", category: "직접경쟁", source: "seed", youtube_channel_id: "UCmulti")
    v1 = ch.videos.create!(youtube_video_id: "mv1", title: "a")
    v2 = ch.videos.create!(youtube_video_id: "mv2", title: "b")
    # 두 영상 각각 100일치(같은 주에 여러 일)
    [v1, v2].each { |v| (91..100).each { |i| VideoDailyStat.create!(video: v, date: today - i, view_count: i) } }

    Snapshot::RollupOldStats.call(today: today)

    # 각 영상은 자기 주 그룹에서만 씨닝 — 서로의 행을 지우지 않는다.
    assert_operator v1.daily_stats.count, :>=, 1
    assert_operator v2.daily_stats.count, :>=, 1
    # 그룹 키에 owner_id 가 있으므로 v1·v2 가 같은 주라도 각각 최신 1개는 남는다.
    assert_equal v1.daily_stats.count, v2.daily_stats.count
  end

end
