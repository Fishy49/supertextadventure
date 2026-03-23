import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="game-form"
export default class extends Controller {
  static targets = ["gameType", "worldSelector"]

  connect() {
    this.toggleWorldSelector()
  }

  toggleWorldSelector() {
    const gameType = this.gameTypeTarget.value

    if (gameType === "classic") {
      this.worldSelectorTarget.style.display = "block"
    } else {
      this.worldSelectorTarget.style.display = "none"
    }
  }
}
