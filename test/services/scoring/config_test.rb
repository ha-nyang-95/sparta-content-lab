# Scoring::Config 로더가 AD-4 튜닝 키를 전부 노출하고 단일 소재지에서만 읽음을 검증
require "test_helper"

class Scoring::ConfigTest < ActiveSupport::TestCase
  test "AD-4 키 그룹이 전부 non-nil 로 조회된다" do
    assert_not_nil Scoring::Config.fetch(:baseline, :sample_size_n)
    assert_not_nil Scoring::Config.fetch(:baseline, :min_sample_for_confidence)

    assert_not_nil Scoring::Config.fetch(:performance, :view_floor_fixed)
    assert_not_nil Scoring::Config.fetch(:performance, :view_floor_k)
    assert_equal 25, Scoring::Config.fetch(:performance, :extreme_multiple)
    assert_not_nil Scoring::Config.fetch(:performance, :multiple_presets)

    assert_not_nil Scoring::Config.fetch(:evergreen, :min_age_days)
    assert_not_nil Scoring::Config.fetch(:evergreen, :min_multiple)

    assert_not_nil Scoring::Config.fetch(:similarity, :tau)

    weights = Scoring::Config.fetch(:opportunity_score, :weights)
    assert_not_nil weights.fetch(:performance_signal)
    assert_not_nil weights.fetch(:competitor_commonality)
    assert_not_nil weights.fetch(:content_gap)
    assert_not_nil weights.fetch(:recency)

    # normalization 은 본개발 확정 전까지 빈 Hash 자리 — 존재하고 Hash 여야 한다.
    assert_instance_of Hash, Scoring::Config.fetch(:opportunity_score, :normalization)

    assert_not_nil Scoring::Config.fetch(:subscriber_bands)

    assert_not_nil Scoring::Config.fetch(:cold_start_snapshots, :sparkline)
    assert_not_nil Scoring::Config.fetch(:cold_start_snapshots, :vpd)
    assert_not_nil Scoring::Config.fetch(:cold_start_snapshots, :evergreen_validation)
    assert_not_nil Scoring::Config.fetch(:cold_start_snapshots, :subscriber_delta)

    assert_equal 180, Scoring::Config.fetch(:is_short, :max_duration_seconds)
  end

  test "없는 키 fetch 는 KeyError 를 raise 한다" do
    assert_raises(KeyError) { Scoring::Config.fetch(:performance, :nonexistent_key) }
    assert_raises(KeyError) { Scoring::Config.fetch(:no_such_group) }
  end

  test "로더는 config/scoring.yml 단일 소재지에서만 읽는다" do
    raw = YAML.load_file(Rails.root.join("config/scoring.yml"))
    assert_equal raw["performance"]["extreme_multiple"],
                 Scoring::Config.fetch(:performance, :extreme_multiple)
    assert_equal raw["is_short"]["max_duration_seconds"],
                 Scoring::Config.fetch(:is_short, :max_duration_seconds)
  end
end
