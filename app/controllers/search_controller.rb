# 헤더 실시간 검색(타입어헤드) — 제목 부분일치 상위 5건 + 전체 개수를 JSON 으로. 읽기 전용(AD-3)
class SearchController < ApplicationController
  LIMIT = 5      # 기본 드롭다운 노출 수.
  MAX_ALL = 50   # '모두 보기'로 펼칠 때 드롭다운 내부 스크롤로 보여줄 상한(과다 렌더 방지).

  def index
    q = helpers.search_query(params) # strip + 100자 상한(7.1 정규화 재사용).
    return render json: { results: [], total: 0, q: "" } if q.blank?

    # 제목 부분일치 — sanitize_sql_like 로 %·_ 이스케이프 + ESCAPE '\'(SQLite 기본 이스케이프 없음). 미제외 채널만.
    scope = Video.joins(:channel).where(channels: { excluded: false })
                 .where("videos.title LIKE ? ESCAPE ?", "%#{Video.sanitize_sql_like(q)}%", "\\")

    # all=1 이면 드롭다운 내부 스크롤용으로 더 많이(MAX_ALL), 아니면 상위 5건.
    limit = params[:all].present? ? MAX_ALL : LIMIT
    total = scope.count
    results = scope.order(view_count: :desc).limit(limit).includes(:channel).map do |video|
      { title: video.title, channel: video.channel.name, url: helpers.youtube_watch_url(video) }
    end

    render json: { results: results, total: total, q: q }
  end
end
