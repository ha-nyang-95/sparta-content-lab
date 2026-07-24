# Recommendation — reference_video_ids JSON 직렬화(Array 왕복) 검증
require "test_helper"

class RecommendationTest < ActiveSupport::TestCase
  test "reference_video_ids 는 Array 를 할당·reload 후 Array 로 복원한다" do
    rec = Recommendation.create!(topic_label: "주제", opportunity_score: 42.0, rank: 1,
                                 reference_video_ids: [3, 1, 2])
    rec.reload
    assert_kind_of Array, rec.reference_video_ids
    assert_equal [3, 1, 2], rec.reference_video_ids
  end

  test "reference_video_ids 미지정 시 기본 빈 Array" do
    rec = Recommendation.create!(topic_label: "주제", opportunity_score: 10.0, rank: 1)
    rec.reload
    assert_equal [], rec.reference_video_ids
  end
end
