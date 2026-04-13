import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const item = event.currentTarget
    const details = item.querySelectorAll("[data-inventory-detail]")
    details.forEach(detail => detail.classList.toggle("hidden"))
  }
}
