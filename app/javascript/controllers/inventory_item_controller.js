import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { command: String }

  send() {
    const terminal = window.stimulus_controller("terminalInput", "terminal")
    if (!terminal) { return }

    terminal.inputTarget.textContent = this.commandValue
    terminal.inputTarget.dispatchEvent(new KeyboardEvent("keydown", { keyCode: 13, bubbles: true }))
  }
}
