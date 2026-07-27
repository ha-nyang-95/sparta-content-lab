// 헤더 실시간 검색(타입어헤드) — 입력 시 상위 5건, '모두 보기'는 드롭다운 내부 스크롤로 전체 펼침(박스 크기 고정)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "list", "more"]
  static values = { url: String }

  connect() {
    this.timer = null
    this.lastQuery = ""
    this.onDocClick = this.onDocClick.bind(this)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("click", this.onDocClick)
  }

  // 입력마다 200ms 디바운스 — 매 글자 요청 폭주 방지. 항상 상위 5건부터.
  query() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    this.lastQuery = q
    if (!q) { this.hide(); return }
    this.timer = setTimeout(() => this.fetch(q, false), 200)
  }

  // '모두 보기' — 전체(상한 내)를 불러와 같은 박스 안에서 스크롤로 보여준다(페이지 이동 없음).
  showAll(e) {
    e.preventDefault()
    if (this.lastQuery) this.fetch(this.lastQuery, true)
  }

  async fetch(q, all) {
    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(q)}${all ? "&all=1" : ""}`
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      this.render(await res.json(), all)
    } catch (_e) {
      // 네트워크 일시 오류는 다음 입력에서 회복
    }
  }

  render(data, expanded) {
    if (!data.results || data.results.length === 0) { this.hide(); return }

    this.listTarget.innerHTML = data.results.map((r) => `
      <a href="${r.url}" target="_blank" rel="noopener"
         class="flex flex-col gap-0.5 border-b border-border-subtle px-3 py-2 last:border-b-0 hover:bg-primary-50">
        <span class="truncate text-body text-ink-body" title="${esc(r.title)}">${esc(r.title)}</span>
        <span class="truncate text-caption text-ink-muted">${esc(r.channel)}</span>
      </a>`).join("")

    // 펼치기 전에만 '모두 보기(N)' 노출 — 펼친 뒤엔 스크롤로 보므로 버튼 숨김.
    if (!expanded && data.total > data.results.length) {
      this.moreTarget.textContent = `모두 보기 (${data.total})`
      this.moreTarget.classList.remove("hidden")
    } else {
      this.moreTarget.classList.add("hidden")
    }
    // 펼치면 맨 위부터 스크롤 시작.
    if (expanded) this.listTarget.scrollTop = 0
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
