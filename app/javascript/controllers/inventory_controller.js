import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "details"]

  toggle(event) {
    const button = event.currentTarget
    const li = button.closest("li")
    const detailsId = button.getAttribute("aria-controls")
    const panel = detailsId ? document.getElementById(detailsId) : li.querySelector("[data-inventory-target='details']")

    if (!panel) { return }

    const isExpanded = button.getAttribute("aria-expanded") === "true"

    // Close all other open panels (accordion behaviour)
    this.toggleTargets.forEach((btn) => {
      if (btn === button) { return }
      if (btn.getAttribute("aria-expanded") !== "true") { return }

      const otherId = btn.getAttribute("aria-controls")
      const otherPanel = otherId
        ? document.getElementById(otherId)
        : btn.closest("li").querySelector("[data-inventory-target='details']")

      if (otherPanel) { otherPanel.hidden = true }
      btn.setAttribute("aria-expanded", "false")
    })

    // Toggle the clicked panel
    panel.hidden = isExpanded
    button.setAttribute("aria-expanded", (!isExpanded).toString())
  }
}
