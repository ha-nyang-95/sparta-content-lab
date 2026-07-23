# seed가 운영 2인을 등록하고 재실행해도 idempotent함을 검증하는 테스트
require "test_helper"

class SeedOperatorsTest < ActiveSupport::TestCase
  # seed와 동일한 소스(ENV → 기본값)에서 기대 이메일을 파생한다.
  # 하드코딩하면 CI에 SEED_OPERATOR*_EMAIL이 설정됐을 때 오탐(false failure)이 난다.
  OPERATOR_EMAILS = [
    (ENV["SEED_OPERATOR1_EMAIL"].to_s.strip.presence || "operator1@sparta.local"),
    (ENV["SEED_OPERATOR2_EMAIL"].to_s.strip.presence || "operator2@sparta.local"),
  ].map { |e| e.strip.downcase }.freeze

  test "load_seed는 운영 2인을 등록하고 재실행해도 중복이 없다" do
    Rails.application.load_seed

    OPERATOR_EMAILS.each do |email|
      assert_equal 1, User.where(email_address: email).count,
        "#{email} 운영자가 정확히 1명 존재해야 한다"
    end

    count_after_first = User.where(email_address: OPERATOR_EMAILS).count
    assert_equal 2, count_after_first

    Rails.application.load_seed

    OPERATOR_EMAILS.each do |email|
      assert_equal 1, User.where(email_address: email).count,
        "재실행 후에도 #{email} 운영자는 정확히 1명이어야 한다"
    end
    assert_equal 2, User.where(email_address: OPERATOR_EMAILS).count
  end
end
