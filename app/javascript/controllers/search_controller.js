// 헤더 실시간 검색(타입어헤드) — 입력 시 디바운스 후 상위 5건을 드롭다운에 그리고, 초과분은 '모두 보기'로 인기 페이지로
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "list", "more"]
  static values = { url: String, allUrl: String }

  connect() {
    this.timer = null
    this.onDocClick = this.onDocClick.bind(this)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("click", this.onDocClick)
  }

  // 입력마다 200ms 디바운스 — 매 글자 요청 폭주 방지.
  query() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (!q) { this.hide(); return }
    this.timer = setTimeout(() => this.fetch(q), 200)
  }

  async fetch(q) {
    try {
      const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      this.render(await res.json())
    } catch (_e) {
      // 네트워크 일시 오류는 다음 입력에서 회복
    }
  }

  render(data) {
    if (!data.results || data.results.length === 0) { this.hide(); return }

    this.listTarget.innerHTML = data.results.map((r) => `
      <a href="${r.url}" target="_blank" rel="noopener"
         class="flex flex-col gap-0.5 border-b border-border-subtle px-3 py-2 last:border-b-0 hover:bg-primary-50">
        <span class="truncate text-body text-ink-body" title="${esc(r.title)}">${esc(r.title)}</span>
        <span class="truncate text-caption text-ink-muted">${esc(r.channel)}</span>
      </a>`).join("")

    // 5건 초과면 '모두 보기(N)' → 인기 페이지 전체 검색으로(거기서 스크롤). 드롭다운 자체는 커지지 않는다.
    if (data.total > data.results.length) {
      this.moreTarget.href = `${this.allUrlValue}?q=${encodeURIComponent(data.q)}`
      this.moreTarget.textContent = `모두 보기 (${data.total})`
      this.moreTarget.classList.remove("hidden")
    } else {
      this.moreTarget.classList.add("hidden")
    }
    this.show()
  }

  show() {
    this.resultsTarget.classList.remove("hidden")
    document.addEventListener("click", this.onDocClick)
  }

  hide() {
    this.resultsTarget.classList.add("hidden")
    document.removeEventListener("click", this.onDocClick)
  }

  onDocClick(e) {
    if (!this.element.contains(e.target)) this.hide()
  }
}

// XSS 방어 — 제목·채널명을 텍스트로 이스케이프.
function esc(s) {
  const d = document.createElement("div")
  d.textContent = s == null ? "" : s
  return d.innerHTML
}
