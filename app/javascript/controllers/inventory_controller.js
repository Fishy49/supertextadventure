import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const li = event.currentTarget.closest("li")
    const wasExpanded = event.currentTarget.getAttribute("aria-expanded") === "true"

    this.element.querySelectorAll("li[data-item-id]").forEach(otherLi => {
      if (otherLi === li) return
      const btn = otherLi.querySelector("[data-inventory-target='toggle']")
      if (btn) btn.setAttribute("aria-expanded", "false")
      const art = otherLi.querySelector("[data-inventory-target='art']")
      if (art) art.classList.add("hidden")
      const desc = otherLi.querySelector("[data-inventory-target='description']")
      if (desc) desc.classList.add("hidden")
    })

    const art = li.querySelector("[data-inventory-target='art']")
    const desc = li.querySelector("[data-inventory-target='description']")
    if (art) art.classList.toggle("hidden", wasExpanded)
    if (desc) desc.classList.toggle("hidden", wasExpanded)
    event.currentTarget.setAttribute("aria-expanded", (!wasExpanded).toString())
  }
}
