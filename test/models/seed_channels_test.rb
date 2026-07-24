# seed가 §5 채널을 source:"seed"로 4분류 매핑해 로드하고 재실행해도 idempotent함을 검증
require "test_helper"

class SeedChannelsTest < ActiveSupport::TestCase
  CATEGORIES = %w[직접경쟁 한국어교육일반 언어교육참고 상단퍼널].freeze

  test "load_seed는 source:seed 채널을 생성한다" do
    Rails.application.load_seed
    assert Channel.where(source: "seed").count.positive?,
      "시드 채널이 하나 이상 생성돼야 한다"
  end

  test "모든 시드 채널의 category는 4분류 중 하나다" do
    Rails.application.load_seed
    Channel.where(source: "seed").find_each do |channel|
      assert_includes CATEGORIES, channel.category,
        "#{channel.name}의 category(#{channel.category})가 4분류에 없다"
    end
  end

  test "시드가 4분류를 모두 커버한다" do
    Rails.application.load_seed
    present = Channel.where(source: "seed").distinct.pluck(:category).sort
    assert_equal CATEGORIES.sort, present
  end

  test "load_seed 재실행 시 채널 수가 늘지 않는다(idempotent)" do
    Rails.application.load_seed
    count_after_first = Channel.count
    seed_count_after_first = Channel.where(source: "seed").count

    Rails.application.load_seed
    assert_equal count_after_first, Channel.count
    assert_equal seed_count_after_first, Channel.where(source: "seed").count
  end

  test "§5에서 UC id를 가진 채널은 youtube_channel_id가 설정된다" do
    Rails.application.load_seed
    with_uc = Channel.where(source: "seed").where.not(youtube_channel_id: nil)
    assert with_uc.count.positive?, "UC id를 가진 시드 채널이 하나 이상 있어야 한다"
    with_uc.find_each do |channel|
      assert_match(/\AUC/, channel.youtube_channel_id,
        "#{channel.name}의 youtube_channel_id가 UC로 시작하지 않는다")
    end
  end
end
