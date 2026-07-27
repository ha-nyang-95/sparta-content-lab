// 영상 기획 분석 모달 — 영상 클릭 시 열려 /videos/:id/analysis 를 불러와 도입부·전체 분석을 그린다(온디맨드·캐시). 무자막/실패는 정직 안내.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "loading", "content", "error", "title", "introExcerpt", "introAnalysis", "summary", "overallAnalysis", "link"]

  // 영상 버튼 클릭 — params: title, youtube(영상 URL), analysis(분석 엔드포인트).
  open(e) {
    const { title, youtube, analysis } = e.params
    this.titleTarget.textContent = title || "영상 분석"
    this.linkTarget.href = youtube || "#"
    this.setState("loading")
    this.showModal()
    this.fetch(analysis)
  }

  async fetch(url) {
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) return this.fail("분석을 불러오지 못했습니다.")
      const data = await res.json()
      if (data.status === "ok") {
        this.introExcerptTarget.textContent = data.intro_excerpt || ""
        this.introAnalysisTarget.textContent = data.intro_analysis || ""
        this.summaryTarget.textContent = data.summary || ""
        this.overallAnalysisTarget.textContent = data.overall_analysis || ""
        if (data.url) this.linkTarget.href = data.url
        this.setState("content")
      } else {
        this.fail(data.detail || "이 영상은 분석할 수 없습니다.")
      }
    } catch (_e) {
      this.fail("분석을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.")
    }
  }

  fail(msg) {
    this.errorTarget.textContent = msg
    this.setState("error")
  }

  setState(s) {
    this.loadingTarget.classList.toggle("hidden", s !== "loading")
    this.contentTarget.classList.toggle("hidden", s !== "content")
    this.errorTarget.classList.toggle("hidden", s !== "error")
  }

  showModal() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  backdrop(e) {
    if (e.target === e.currentTarget) this.close()
  }

  closeOnEsc() {
    if (!this.modalTarget.classList.contains("hidden")) this.close()
  }
}
