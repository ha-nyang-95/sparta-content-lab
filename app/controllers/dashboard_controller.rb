# 대시보드 홈(root) — 물질화된 추천·참고 영상·필터 파라미터만 읽는 얇은 컨트롤러(AD-3, 재계산 금지)
class DashboardController < ApplicationController
  def index
    @recommendations = Recommendation.order(:rank)
    reference_ids = @recommendations.flat_map(&:reference_video_ids).uniq
    @videos_by_rec = Video.where(id: reference_ids)
                          .includes(:video_score, :channel)
                          .index_by(&:id)

    @period   = helpers.permitted_period(params)
    @category = helpers.permitted_category(params)
    @type     = helpers.permitted_type(params)
    @layout   = helpers.permitted_layout(params)
    @max_recommendations = Scoring::Config.fetch(:recommendation, :max_count)
  end
end
