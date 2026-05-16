import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event){
    const button = event.currentTarget
    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", (!expanded).toString())

    const description = button.parentElement.querySelector("[data-inventory-target='description']")
    if(description){ description.classList.toggle("hidden") }

    const li = button.closest("li")
    if(li){ li.classList.toggle("inventory-item--expanded") }
  }
}
