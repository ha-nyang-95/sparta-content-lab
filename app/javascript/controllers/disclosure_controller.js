// 근거 보기 펼침 — content 타깃을 토글하고 aria-expanded를 동기화한다(Stimulus disclosure).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger"]

  toggle() {
    const hidden = this.contentTarget.classList.toggle("hidden")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(!hidden))
    }
  }
}
