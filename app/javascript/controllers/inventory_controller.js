import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const button = event.currentTarget
    const li = button.closest("li")
    if (!li) return

    const detail = li.querySelector("[data-inventory-target='detail']")
    const caret = li.querySelector("[data-inventory-target='caret']")

    if (!detail) return

    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", String(!expanded))
    detail.classList.toggle("hidden")
    if (caret) caret.classList.toggle("rotate-90")
    li.classList.toggle("is-open")
  }
}
