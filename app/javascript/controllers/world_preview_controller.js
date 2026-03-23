import { Controller } from "@hotwired/stimulus"

// Simplified controller - just triggers backend preview updates
export default class extends Controller {
  static values = {
    worldId: Number
  }

  connect() {
    // Listen for changes from the editor
    window.addEventListener("world-data-changed", this.handleWorldDataChanged.bind(this))
  }

  disconnect() {
    window.removeEventListener("world-data-changed", this.handleWorldDataChanged.bind(this))
  }

  handleWorldDataChanged(event) {
    this.updatePreview(event.detail.json)
  }

  async updatePreview(jsonString) {
    try {
      // Validate JSON first
      JSON.parse(jsonString)

      // Send to backend to render preview
      const worldId = this.worldIdValue
      const response = await fetch(`/worlds/${worldId}/preview`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ world_data: jsonString })
      })

      if (response.ok) {
        const turboStream = await response.text()
        Turbo.renderStreamMessage(turboStream)
      }
    } catch (error) {
      // Show error in preview
      const event = new CustomEvent("preview-error", {
        detail: { error: error.message }
      })
      window.dispatchEvent(event)
    }
  }
}
