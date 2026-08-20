import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event){
    const button = event.currentTarget
    const description = button.parentElement.querySelector("[data-inventory-target='description']")
    if(!description){ return }

    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", (!expanded).toString())
    description.classList.toggle("hidden")
  }
}
