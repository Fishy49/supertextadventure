import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    // Slide in after a brief delay to allow Turbo to render
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.panelTarget.style.transform = 'translateX(0)'
      })
    })
  }

  close(event) {
    event.preventDefault()

    // Slide out
    this.panelTarget.style.transform = 'translateX(100%)'

    // Clear the turbo frame after animation completes
    setTimeout(() => {
      const frame = document.getElementById('entity-modal')
      if (frame) {
        frame.innerHTML = ''
      }
    }, 300)
  }

  clickOutside(event) {
    // Close if clicking the backdrop (not the panel)
    if (event.target === this.element) {
      this.close(event)
    }
  }
}
