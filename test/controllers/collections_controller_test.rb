# CollectionsController — 수집 트리거(enqueue·중복 차단)·진행 상태 JSON 검증
require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as(User.take) }

  test "POST create — 진행 중이 없으면 DailyCollectionJob 을 enqueue 하고 notice 로 리다이렉트" do
    assert_enqueued_with(job: DailyCollectionJob) do
      post collections_path
    end
    assert_redirected_to root_path
    assert_equal "수집을 시작했습니다. 완료까지 몇 분 걸립니다.", flash[:notice]
  end

  test "POST create — 이미 running 이면 중복 enqueue 하지 않고 alert" do
    JobRun.start!("DailyCollectionJob") # running 상태 선점.

    assert_no_enqueued_jobs(only: DailyCollectionJob) do
      post collections_path
    end
    assert_equal "이미 수집이 진행 중입니다.", flash[:alert]
  end

  test "GET status — 진행 중이 없으면 running:false·progress:0" do
    get collection_status_path
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal false, body["running"]
    assert_equal 0, body["progress"]
  end

  test "GET status — running 잡의 단계·진행률을 반영한다" do
    run = JobRun.start!("DailyCollectionJob")
    run.mark_progress!(phase: "임베딩", progress: 45)

    get collection_status_path
    body = JSON.parse(@response.body)
    assert_equal true, body["running"]
    assert_equal "임베딩", body["phase"]
    assert_equal 45, body["progress"]
  end

  test "GET status — 마지막 완료 시각·상태를 담는다" do
    JobRun.create!(job_name: "DailyCollectionJob", status: "succeeded",
                   started_at: 2.hours.ago, finished_at: 1.hour.ago, progress: 100)

    get collection_status_path
    body = JSON.parse(@response.body)
    assert_equal false, body["running"]
    assert_equal "succeeded", body["last_status"]
    assert_not_nil body["last_finished_at"]
  end
end
