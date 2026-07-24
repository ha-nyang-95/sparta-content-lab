# DailyCollectionJob — 정상 수집(JobRun succeeded·쿼터·스냅샷)·채널별 회복·retry_on 설정 검증
require "test_helper"

class DailyCollectionJobTest < ActiveSupport::TestCase
  def make_channel(name:, youtube_channel_id:)
    Channel.create!(name: name, category: "직접경쟁", source: "seed", youtube_channel_id: youtube_channel_id)
  end

  test "정상 실행: JobRun succeeded·quota_used 기록·영상·스냅샷 물질화" do
    make_channel(name: "a", youtube_channel_id: "UCaaa")
    make_channel(name: "b", youtube_channel_id: "UCbbb")

    DailyCollectionJob.perform_now

    run = JobRun.last
    assert_equal "DailyCollectionJob", run.job_name
    assert_equal "succeeded", run.status
    assert_not_nil run.started_at
    assert_not_nil run.finished_at
    assert_kind_of Integer, run.quota_used
    assert run.quota_used >= 0, "stub 이 쿼터를 과금하므로 >= 0"
    assert Video.count > 0, "영상이 물질화돼야 한다"
    assert VideoDailyStat.count > 0, "일별 스냅샷이 기록돼야 한다"
  end

  test "스코어링 스테이지 append: 스냅샷 뒤 기준선·성과배수가 물질화되고 런은 succeeded" do
    make_channel(name: "a", youtube_channel_id: "UCaaa")
    make_channel(name: "b", youtube_channel_id: "UCbbb")

    DailyCollectionJob.perform_now

    run = JobRun.last
    assert_equal "succeeded", run.status
    assert VideoDailyStat.count > 0, "스코어링은 스냅샷 뒤 append — 스냅샷 물질화가 선행돼야 한다"
    assert Baseline.count > 0, "기준선 스테이지가 append 실행돼야 한다"
    assert VideoScore.count > 0, "성과배수 스테이지가 append 실행돼야 한다"

    # 순서 불변식 — 물질화된 VideoScore 의 영상은 자기 채널의 기준선을 가진다(baseline→performance 순).
    VideoScore.joins(:video).includes(video: :channel).each do |score|
      assert Baseline.exists?(channel_id: score.video.channel_id),
             "성과배수를 받은 영상의 채널은 기준선이 먼저 물질화돼 있어야 한다"
    end
  end

  test "채널별 회복: 한 채널 실패해도 런은 succeeded·스냅샷은 기록된다" do
    make_channel(name: "good", youtube_channel_id: "UCgood")
    bad = make_channel(name: "bad", youtube_channel_id: "UCbad")

    # Minitest 6 에는 any_instance 도 stub 도 없다 — 클래스의 .new 를 직접 임시 교체해, 문제
    # 채널에만 실패를 주입하고 나머지는 실제 FetchChannelVideos 로 위임하는 래퍼를 반환한다.
    real_new = Youtube::FetchChannelVideos.method(:new)
    Youtube::FetchChannelVideos.define_singleton_method(:new) do |**kwargs|
      SelectiveFetcher.new(real_new.call(**kwargs), bad.id)
    end

    begin
      DailyCollectionJob.perform_now
    ensure
      # 인젝트한 싱글턴 .new 를 제거해 상속된 Class#new 로 되돌린다.
      Youtube::FetchChannelVideos.singleton_class.send(:remove_method, :new)
    end

    run = JobRun.last
    assert_equal "succeeded", run.status, "한 채널 실패가 런 전체를 중단시키면 안 된다"
    assert VideoDailyStat.count > 0, "실패 채널이 있어도 스냅샷 단계는 실행돼야 한다"
    assert_equal 1, run.channels_failed, "실패 채널 수가 기록돼야 한다(부분 실패 관측)"
    assert_equal 1, run.channels_processed
  end

  test "전 채널 실패는 succeeded 로 위장하지 않고 failed 로 기록된다(정직성)" do
    a = make_channel(name: "a", youtube_channel_id: "UCa1")
    b = make_channel(name: "b", youtube_channel_id: "UCb1")

    real_new = Youtube::FetchChannelVideos.method(:new)
    Youtube::FetchChannelVideos.define_singleton_method(:new) do |**kwargs|
      AllFailFetcher.new
    end
    begin
      DailyCollectionJob.perform_now
    ensure
      Youtube::FetchChannelVideos.singleton_class.send(:remove_method, :new)
    end

    run = JobRun.last
    assert_equal "failed", run.status, "전 채널 실패는 failed 여야 한다"
    assert_equal 2, run.channels_failed
    assert_equal 0, run.channels_processed
  end

  test "Epic 4 스테이지 append: 스코어링 뒤 임베딩이 물질화되고 런은 succeeded" do
    make_channel(name: "a", youtube_channel_id: "UCe4a")
    make_channel(name: "b", youtube_channel_id: "UCe4b")

    DailyCollectionJob.perform_now

    run = JobRun.last
    assert_equal "succeeded", run.status
    # 임베딩 스테이지가 스코어링 뒤 append 실행됐다는 신호 — 제목 있는 영상에 임베딩이 물질화됨.
    assert Video.where.not(embedding: nil).count > 0,
      "Epic 4 임베딩 스테이지가 에버그린 뒤 append 실행돼야 한다"
  end

  test "retry_on 은 일시 인프라 오류(Deadlocked)만 대상이고 YouTube RateLimited 는 아니다" do
    handled = DailyCollectionJob.rescue_handlers.map(&:first)
    assert_includes handled, "ActiveRecord::Deadlocked", "일시 DB 오류는 잡 단위 재시도"
    assert_not_includes handled, "Youtube::RateLimited", "YouTube rate 오류는 경계·채널별 처리(잡 재시도 아님)"
  end

  test "reap_stale! 는 중단된 오래된 running 실행을 failed 로 회수한다" do
    stale = JobRun.create!(job_name: "X", status: "running", started_at: 7.hours.ago)
    fresh = JobRun.create!(job_name: "X", status: "running", started_at: 1.minute.ago)

    JobRun.reap_stale!

    assert_equal "failed", stale.reload.status
    assert_not_nil stale.finished_at
    assert_equal "running", fresh.reload.status, "최근 실행은 회수하지 않는다"
  end

  test "전 채널 스코어링 실패는 succeeded 로 위장하지 않고 failed 로 기록된다(정직성)" do
    make_channel(name: "a", youtube_channel_id: "UCscore1")
    make_channel(name: "b", youtube_channel_id: "UCscore2")

    # 수집은 정상(stub), 스코어링 첫 스테이지를 전 채널 실패시킨다 — .new 를 raise 로 임시 교체.
    Scoring::CalculateBaseline.define_singleton_method(:new) { |_channel| raise "boom(스코어링)" }
    begin
      DailyCollectionJob.perform_now
    ensure
      Scoring::CalculateBaseline.singleton_class.send(:remove_method, :new)
    end

    run = JobRun.last
    assert_equal "failed", run.status, "전 채널 스코어링 실패는 체계적 문제 — failed 여야 한다"
    assert VideoDailyStat.count > 0, "수집·스냅샷은 성공했어야 한다(스코어링만 실패)"
  end

  test "스코어링은 수집 스코프와 동일 — youtube_channel_id 없는 handle-only 채널은 기준선을 만들지 않는다" do
    fetched = make_channel(name: "fetched", youtube_channel_id: "UChandle1")
    handle_only = Channel.create!(name: "handle-only", category: "직접경쟁", source: "seed", handle: "@handleonly")

    DailyCollectionJob.perform_now

    assert Baseline.exists?(channel_id: fetched.id), "수집 대상 채널은 스코어링된다"
    assert_not Baseline.exists?(channel_id: handle_only.id),
      "youtube_channel_id 없는 채널은 스코어링 스코프 밖 — 빈 기준선을 만들지 않는다"
  end

  # 전 채널을 실패시키는 fetcher(체계적 실패 시뮬레이션).
  class AllFailFetcher
    def call(_channel) = raise "boom(전채널)"
  end

  # 특정 채널에만 실패를 주입하는 fetcher 래퍼 — 나머지 채널은 실제 인스턴스에 위임한다.
  class SelectiveFetcher
    def initialize(real, bad_channel_id)
      @real = real
      @bad_channel_id = bad_channel_id
    end

    def call(channel)
      raise "boom(주입 실패)" if channel.id == @bad_channel_id

      @real.call(channel)
    end
  end
end
