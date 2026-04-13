import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  observer = null

  connect() {
    setTimeout(() => {
      this.observer = new MutationObserver((mutationsList) => {
        for (const mutation of mutationsList) {
          if (mutation.type === "childList") {
            mutation.addedNodes.forEach((node) => {
              if (node.nodeType === Node.ELEMENT_NODE && node.classList.contains("game-message")) {
                setTimeout(() => this.enhanceInventoryMessage(node), 0)
              }
            })
          }
        }
      })
      this.observer.observe(this.element, { childList: true, subtree: true })
    }, 0)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  enhanceInventoryMessage(messageNode) {
    const text = messageNode.textContent || ""
    if (!text.includes("INVENTORY") || !text.includes("╔")) {
      return
    }

    const paragraphs = messageNode.querySelectorAll("p")
    paragraphs.forEach((p) => {
      const lines = p.innerHTML.split(/<br\s*\/?>/i)
      const enhanced = lines.map((line) => {
        const plainText = line.replace(/<[^>]+>/g, "")
        const match = plainText.match(/^║\s(.{3})\s(.+?)\s*║\s*$/)
        if (match) {
          const itemName = match[2].trim()
          if (itemName && !itemName.match(/^\d+ items?$/) && !itemName.startsWith("INVENTORY")) {
            const escaped = itemName.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            return line.replace(
              plainText,
              plainText.replace(
                itemName,
                `<span class="inventory-item-line" data-item-name="${escaped}">${escaped}</span>`
              )
            )
          }
        }
        return line
      })
      p.innerHTML = enhanced.join("<br>")
    })

    messageNode.querySelectorAll(".inventory-item-line").forEach((span) => {
      span.addEventListener("click", (e) => {
        const name = e.currentTarget.dataset.itemName
        if (!name) return
        const input = document.querySelector(".terminal-input[contenteditable]")
        if (!input) return
        input.textContent = "EXAMINE " + name
        const event = new KeyboardEvent("keydown", { keyCode: 13, bubbles: true, cancelable: true })
        input.dispatchEvent(event)
      })
    })
  }
}
