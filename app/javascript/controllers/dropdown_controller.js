// <details> 드롭다운 자동 닫힘 — 열릴 때 다른 열린 드롭다운을 닫고, 바깥을 클릭하면 닫는다(Stimulus).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._onDocClick = (e) => {
      if (!this.element.contains(e.target)) this.element.removeAttribute("open")
    }
    this._onToggle = () => {
      if (this.element.open) {
        // 다른 열린 dropdown 을 닫아 하나만 열리게 한다.
        document.querySelectorAll("details[data-controller~='dropdown'][open]").forEach((d) => {
          if (d !== this.element) d.removeAttribute("open")
        })
        document.addEventListener("click", this._onDocClick)
      } else {
        document.removeEventListener("click", this._onDocClick)
      }
    }
    this.element.addEventListener("toggle", this._onToggle)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this._onToggle)
    document.removeEventListener("click", this._onDocClick)
  }
}
