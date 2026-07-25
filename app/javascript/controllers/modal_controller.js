// 모달 열기/닫기 — 트리거로 dialog 타깃을 표시하고, 백드롭 클릭·ESC·닫기 버튼으로 닫는다(Stimulus).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this._onKey = (e) => { if (e.key === "Escape") this.close() }
  }

  open() {
    this.dialogTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKey)
    this.dialogTarget.querySelector("[data-modal-focus]")?.focus()
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKey)
  }

  // 백드롭(자기 자신) 클릭 시에만 닫는다 — 내부 클릭은 무시.
  backdrop(e) {
    if (e.target === e.currentTarget) this.close()
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
    document.body.classList.remove("overflow-hidden")
  }
}
