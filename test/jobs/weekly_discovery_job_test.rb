# WeeklyDiscoveryJob — 발굴 채널(source:auto) 추가·JobRun succeeded·search 쿼터·idempotent dedup 검증
require "test_helper"

class WeeklyDiscoveryJobTest < ActiveSupport::TestCase
  test "정상 실행: source auto 채널 추가·JobRun succeeded·search 쿼터·channels_processed 기록" do
    WeeklyDiscoveryJob.perform_now

    autos = Channel.where(source: "auto")
    assert_includes autos.pluck(:youtube_channel_id), "UC_stub_discovered_channel"
    channel = autos.find_by(youtube_channel_id: "UC_stub_discovered_channel")
    assert Channel::CATEGORIES.include?(channel.category), "발굴 채널 category 는 4분류 중 하나"

    run = JobRun.where(job_name: "WeeklyDiscoveryJob").last
    assert_equal "succeeded", run.status
    assert_kind_of Integer, run.quota_used
    assert run.quota_used > 0, "search 버킷을 소비해야 한다(키워드당 1콜)"
    assert_equal autos.count, run.channels_processed, "추가한 채널 수를 기록"
  end

  test "idempotent: 두 번 실행해도 auto 채널이 중복 생성되지 않는다" do
    WeeklyDiscoveryJob.perform_now
    count_after_first = Channel.where(source: "auto").count
    WeeklyDiscoveryJob.perform_now
    assert_equal count_after_first, Channel.where(source: "auto").count, "중복 추가 없음"

    run = JobRun.where(job_name: "WeeklyDiscoveryJob").last
    assert_equal 0, run.channels_processed, "두 번째 실행은 신규 추가 0"
  end

  test "이미 존재하는 채널은 재추가되지 않고 에러도 나지 않는다" do
    Channel.create!(name: "기존", category: "직접경쟁", source: "seed",
                    youtube_channel_id: "UC_stub_discovered_channel")

    assert_nothing_raised { WeeklyDiscoveryJob.perform_now }

    assert_equal 1, Channel.where(youtube_channel_id: "UC_stub_discovered_channel").count
    assert_equal 0, Channel.where(source: "auto").count, "기존 채널은 auto 로 재생성 안 함"

    run = JobRun.where(job_name: "WeeklyDiscoveryJob").last
    assert_equal "succeeded", run.status
  end

  test "쿼터 소진 시 발굴이 부분 후보로 graceful 하게 계속된다" do
    # search 버킷을 0으로 만든 원장·클라이언트를 주입하면 첫 search 에서 QuotaExceeded → DiscoverChannels 가 부분(빈) 반환.
    ledger = Youtube::QuotaLedger.new(search_limit: 0)
    client = Youtube::Client.new(ledger: ledger, sleep: ->(_) {})
    candidates = Youtube::DiscoverChannels.new(client: client).call
    assert_equal({}, candidates, "쿼터 0이면 후보 없이 graceful 반환(예외 전파 안 함)")
  end

end
