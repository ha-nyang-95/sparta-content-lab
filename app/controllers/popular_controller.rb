# 인기 콘텐츠 — 물질화된 급상승 스코어(성과 배수 desc)를 필터·프리로드·밴드 그룹핑만 하는 얇은 읽기 전용 컨트롤러(AD-3, 재계산 금지)
class PopularController < ApplicationController
  def index
    @period   = helpers.permitted_period(params)
    @category = helpers.permitted_category(params)
    @type     = helpers.permitted_type(params)
    @layout   = helpers.permitted_layout(params)

    scope = VideoScore.ranked.joins(video: :channel).where(channels: { excluded: false })
    scope = apply_filters(scope)

    @scores = scope.includes(video: [:channel, :daily_stats]).to_a

    @grouped =
      if @layout == "band"
        # nil 밴드는 자기 그룹, 티어 0..3 → nil 순으로. 밴드 내 순서는 ranked(성과 배수 desc) 유지.
        # 정렬 센티넬은 Float::INFINITY — 밴드 티어가 튜닝(AD-4)으로 늘어도 nil 이 항상 마지막.
        @scores.group_by { |s| s.video.channel.subscriber_band }
               .sort_by { |band, _| band.nil? ? Float::INFINITY : band }
      end
  end

  private

  # 6.2 defer 필터 실현 — 기간(업로드 경과/에버그린)·카테고리·유형을 Video/Channel 스코프에 적용(기본/all 은 미적용).
  def apply_filters(scope)
    case @period
    when "1w"        then scope = scope.where("videos.published_at >= ?", 7.days.ago)
    when "1m"        then scope = scope.where("videos.published_at >= ?", 30.days.ago)
    when "3m"        then scope = scope.where("videos.published_at >= ?", 90.days.ago)
    when "evergreen" then scope = scope.where(evergreen_candidate: true)
    end

    scope = scope.where(channels: { category: @category }) unless @category == "all"

    case @type
    when "long"  then scope = scope.where(videos: { is_short: false })
    when "short" then scope = scope.where(videos: { is_short: true })
    end

    scope
  end
end
