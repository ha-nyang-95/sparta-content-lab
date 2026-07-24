// 모바일 좌측 내비 드로어 (Story 1.4). 데스크톱(md+)에서는 CSS로 상시 표시된다.
// 닫힌 상태에서는 패널을 inert 처리해 화면 밖 링크가 포커스/스크린리더에 잡히지 않게 하고,
// 리사이즈로 데스크톱↔모바일을 오갈 때 stuck-open 상태를 리셋한다.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle"]

  connect() {
    this.mq = window.matchMedia("(min-width: 768px)") // Tailwind `md`
    this.onBreakpoint = () => this.sync()
    this.mq.addEventListener("change", this.onBreakpoint)
    this.sync()
  }

  disconnect() {
    if (this.mq) this.mq.removeEventListener("change", this.onBreakpoint)
  }

  toggle() {
    this.isOpen() ? this.close() : this.open()
  }

  open() {
    if (this.isDesktop()) return
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.inert = false
    this.panelTarget.setAttribute("aria-hidden", "false")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
    this.setExpanded(true)
    const first = this.panelTarget.querySelector("a, button")
    if (first) first.focus()
  }

  // event(백드롭 클릭)로 호출되면 focusToggle=true(트리거로 포커스 복귀), sync()에서는 false.
  close({ focusToggle = true } = {}) {
    this.panelTarget.classList.add("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
    this.setExpanded(false)
    if (!this.isDesktop()) {
      this.panelTarget.inert = true
      this.panelTarget.setAttribute("aria-hidden", "true")
    }
    if (focusToggle && this.hasToggleTarget) this.toggleTarget.focus()
  }

  closeOnEsc(event) {
    if (event.key === "Escape" && this.isOpen()) this.close()
  }

  // 데스크톱: 항상 표시·focusable·backdrop 숨김. 모바일: 닫힘(inert)으로 리셋(포커스 이동 없음).
  sync() {
    if (this.isDesktop()) {
      this.panelTarget.classList.remove("-translate-x-full")
      this.panelTarget.inert = false
      this.panelTarget.setAttribute("aria-hidden", "false")
      if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
      this.setExpanded(false)
    } else {
      this.close({ focusToggle: false })
    }
  }

  isDesktop() { return this.mq && this.mq.matches }
  isOpen() { return !this.panelTarget.classList.contains("-translate-x-full") }
  setExpanded(value) {
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", String(value))
  }
}
