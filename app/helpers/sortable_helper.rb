# 표 칼럼 헤더 정렬(3중 상태: 없음→내림차순→오름차순→없음) — 인기·콘텐츠갭·저장 표 공유(§4.3)
module SortableHelper
  # 정렬 키 → ORDER BY 대상(SQL). videos·video_scores 가 조인된 스코프에서만 유효.
  SORT_COLUMNS = {
    "uploaded" => "videos.published_at",
    "views"    => "videos.view_count",
    "multiple" => "video_scores.performance_multiple"
  }.freeze

  def sort_column(params)
    params[:sort] if SORT_COLUMNS.key?(params[:sort])
  end

  def sort_direction(params)
    %w[asc desc].include?(params[:dir]) ? params[:dir] : nil
  end

  # 정렬 가능한 <th> — 클릭 시 none→desc→asc→none 순환. 화살표로 현재 상태 표시.
  def sortable_th(label, key, base_path)
    active_dir = (sort_column(params) == key) && sort_direction(params)

    next_query =
      if !active_dir
        request.query_parameters.merge("sort" => key, "dir" => "desc")
      elsif active_dir == "desc"
        request.query_parameters.merge("sort" => key, "dir" => "asc")
      else
        request.query_parameters.except("sort", "dir") # asc → 기본(정렬 해제)
      end

    arrow = active_dir ? (active_dir == "asc" ? "▲" : "▼") : "↕"
    tag.th(class: "p-2 font-medium") do
      link_to("#{base_path}?#{next_query.to_query}",
              class: "inline-flex items-center gap-1 #{active_dir ? "text-primary-600" : "hover:text-ink-body"}") do
        safe_join([label, tag.span(arrow, class: "text-[9px] #{active_dir ? "text-primary-600" : "text-ink-subtle"}", "aria-hidden": true)])
      end
    end
  end

  # 스코프에 칼럼 정렬 적용 — 파라미터 없으면 default_order(SQL 문자열). videos·video_scores 조인 전제, video_id asc 타이브레이크.
  def apply_video_sort(scope, params, default_order)
    col = sort_column(params)
    dir = sort_direction(params)
    return scope.order(Arel.sql(default_order)) unless col && dir

    nulls = dir == "asc" ? "NULLS FIRST" : "NULLS LAST"
    scope.order(Arel.sql("#{SORT_COLUMNS[col]} #{dir.upcase} #{nulls}")).order(video_id: :asc)
  end
end
