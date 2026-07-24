# JobRun — 상태 전이(start!/succeed!/fail!)·status 포함성·job_name 존재성 검증
require "test_helper"

class JobRunTest < ActiveSupport::TestCase
  test "start! 는 running 상태로 started_at 을 찍어 생성한다" do
    run = JobRun.start!("DailyCollectionJob")

    assert run.persisted?
    assert_equal "DailyCollectionJob", run.job_name
    assert_equal "running", run.status
    assert_not_nil run.started_at
    assert_nil run.finished_at
    assert_equal 0, run.retries
  end

  test "succeed! 는 succeeded 로 전이하고 finished_at·quota_used 를 기록한다" do
    run = JobRun.start!("DailyCollectionJob")
    run.succeed!(quota_used: 42)

    assert_equal "succeeded", run.status
    assert_not_nil run.finished_at
    assert_equal 42, run.quota_used
  end

  test "fail! 는 failed 로 전이하고 finished_at·error·quota_used 를 기록한다" do
    run = JobRun.start!("DailyCollectionJob")
    run.fail!(error: "boom", quota_used: 7)

    assert_equal "failed", run.status
    assert_not_nil run.finished_at
    assert_equal "boom", run.error
    assert_equal 7, run.quota_used
  end

  test "status 는 running/succeeded/failed 만 허용한다" do
    run = JobRun.new(job_name: "X", status: "bogus")
    assert_not run.valid?
    assert_includes run.errors[:status], "is not included in the list"
  end

  test "job_name 은 필수다" do
    run = JobRun.new(status: "running")
    assert_not run.valid?
    assert_includes run.errors[:job_name], "can't be blank"
  end
end
