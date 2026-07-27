# 헤더 실시간 검색(타입어헤드) — 제목 부분일치 상위 5건 + 전체 개수를 JSON 으로. 읽기 전용(AD-3)
class SearchController < ApplicationController
  LIMIT = 5 # 드롭다운 최대 노출 수 — 초과분은 '모두 보기'로 인기 페이지 전체 검색으로 넘긴다.

  def index
    q = helpers.search_query(params) # strip + 100자 상한(7.1 정규화 재사용).
    return render json: { results: [], total: 0, q: "" } if q.blank?

    # 제목 부분일치 — sanitize_sql_like 로 %·_ 이스케이프 + ESCAPE '\'(SQLite 기본 이스케이프 없음). 미제외 채널만.
    scope = Video.joins(:channel).where(channels: { excluded: false })
                 .where("videos.title LIKE ? ESCAPE ?", "%#{Video.sanitize_sql_like(q)}%", "\\")

    total = scope.count
    results = scope.order(view_count: :desc).limit(LIMIT).includes(:channel).map do |video|
      { title: video.title, channel: video.channel.name, url: helpers.youtube_watch_url(video) }
    end

    render json: { results: results, total: total, q: q }
  end
end
