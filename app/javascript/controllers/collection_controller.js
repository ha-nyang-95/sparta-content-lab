// '오늘 업데이트' 진행 게이지 — 상태 JSON 을 3초 폴링해 단계·진행률을 그리고, 완료 시 새 데이터 반영 위해 새로고침
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["idle", "running", "button", "lastRun", "phase", "percent", "bar"]
  static values = { statusUrl: String }

  connect() {
    this.wasRunning = false
    this.fetchStatus()
  }

  disconnect() {
    this.stopPolling()
  }

  async fetchStatus() {
    try {
      const res = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      this.render(await res.json())
    } catch (_e) {
      // 네트워크 일시 오류는 다음 폴링에서 회복
    }
  }

  render(data) {
    if (data.running) {
      this.wasRunning = true
      this.idleTarget.classList.add("hidden")
      this.runningTarget.classList.remove("hidden")
      const pct = Math.max(0, Math.min(100, data.progress || 0))
      this.barTarget.style.width = `${pct}%`
      this.percentTarget.textContent = `${pct}%`
      if (data.phase) this.phaseTarget.textContent = `${data.phase}…`
      this.startPolling()
      return
    }

    this.stopPolling()
    // 방금 완료됐으면(진행 중 → 종료) 새 추천·게이지 데이터 반영 위해 한 번 새로고침.
    if (this.wasRunning) {
      this.wasRunning = false
      window.location.reload()
      return
    }
    this.runningTarget.classList.add("hidden")
    this.idleTarget.classList.remove("hidden")
    this.renderLastRun(data.last_finished_at)
  }

  renderLastRun(iso) {
    if (!iso) return
    const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60000)
    let text
    if (mins < 1) text = "방금"
    else if (mins < 60) text = `${mins}분 전`
    else if (mins < 1440) text = `${Math.floor(mins / 60)}시간 전`
    else text = `${Math.floor(mins / 1440)}일 전`
    this.lastRunTarget.textContent = `마지막 수집: ${text}`
    this.lastRunTarget.classList.remove("hidden")
  }

  startPolling() {
    if (this.pollTimer) return
    this.pollTimer = setInterval(() => this.fetchStatus(), 3000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }
}
