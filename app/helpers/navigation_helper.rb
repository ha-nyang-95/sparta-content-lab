# 좌측 내비 6항목 정의와 현재 컨트롤러 기준 활성 판정·토큰 클래스를 제공하는 헬퍼 (Story 1.4)
module NavigationHelper
  NavItem = Struct.new(:label, :path_name, :controller, :icon, keyword_init: true)

  # 순서·라벨은 DESIGN.md §4.1 / IA §11 고정.
  NAV_ITEMS = [
    NavItem.new(label: "대시보드",   path_name: :root_path,        controller: "dashboard",   icon: :grid),
    NavItem.new(label: "인기 콘텐츠", path_name: :popular_path,     controller: "popular",     icon: :fire),
    NavItem.new(label: "경쟁 채널",   path_name: :competitors_path, controller: "competitors", icon: :users),
    NavItem.new(label: "콘텐츠 갭",   path_name: :content_gap_path, controller: "content_gap", icon: :puzzle),
    NavItem.new(label: "저장한 영상", path_name: :saved_path,       controller: "saved",       icon: :bookmark),
    NavItem.new(label: "설정",       path_name: :settings_path,    controller: "settings",    icon: :cog)
  ].freeze

  def nav_items
    NAV_ITEMS
  end

  # 현재 컨트롤러명으로 활성 항목 판정 (DashboardController → "dashboard").
  def nav_active?(item)
    controller_name == item.controller
  end

  # 활성=primary-600/흰 텍스트, 비활성=muted + hover primary-50 (DESIGN.md §4.1, §10 토큰만).
  def nav_item_classes(item)
    base = "flex items-center gap-3 rounded-control px-3 py-2.5 text-nav transition"
    state =
      if nav_active?(item)
        "bg-primary-600 text-white"
      else
        "text-ink-muted hover:bg-primary-50 hover:text-primary-600"
      end
    "#{base} #{state}"
  end

  # 내비 아이콘 인라인 SVG — stroke=currentColor 로 활성/비활성 텍스트 색을 상속한다.
  def nav_icon(key)
    paths = {
      grid:     '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
      fire:     '<path d="M12 3c1 3-1 4-1 6a3 3 0 0 0 3 3c1 0 2-1 2-2 2 2 2 4 2 5a6 6 0 1 1-12 0c0-3 2-5 3-7 1 2 2 2 3 1 1-1 0-4-3-6z"/>',
      users:    '<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M16 6a3 3 0 0 1 0 6"/><path d="M17 20a6 6 0 0 0-3-5"/>',
      puzzle:   '<path d="M10 4a2 2 0 1 1 4 0v1h2a1 1 0 0 1 1 1v2h1a2 2 0 1 1 0 4h-1v3a1 1 0 0 1-1 1h-3v-1a2 2 0 1 0-4 0v1H5a1 1 0 0 1-1-1v-3H3a2 2 0 1 1 0-4h1V6a1 1 0 0 1 1-1h2V4z"/>',
      bookmark: '<path d="M6 4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v16l-6-4-6 4z"/>',
      cog:      '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/>'
    }
    tag.svg(
      viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      "stroke-width": "1.7", "stroke-linecap": "round", "stroke-linejoin": "round",
      class: "h-5 w-5"
    ) { paths.fetch(key, "").html_safe }
  end
end
