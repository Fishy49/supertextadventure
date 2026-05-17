import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "description", "detail"]
  static values = { singleOpen: { type: Boolean, default: true } }

  connect() {
    this.detailTargets.forEach(detail => detail.classList.add("hidden"))
    this.toggleTargets.forEach(toggle => toggle.setAttribute("aria-expanded", "false"))
  }

  toggle(event) {
    const button = event.currentTarget
    const li = button.closest("li")
    const detail = li.querySelector("[data-inventory-target='detail']")
    const isExpanded = button.getAttribute("aria-expanded") === "true"

    if (this.singleOpenValue && !isExpanded) {
      // Close all others
      this.toggleTargets.forEach(t => {
        if (t !== button) {
          t.setAttribute("aria-expanded", "false")
          const otherLi = t.closest("li")
          const otherDetail = otherLi.querySelector("[data-inventory-target='detail']")
          if (otherDetail) otherDetail.classList.add("hidden")
        }
      })
    }

    button.setAttribute("aria-expanded", String(!isExpanded))
    if (detail) detail.classList.toggle("hidden", isExpanded)
  }
}
