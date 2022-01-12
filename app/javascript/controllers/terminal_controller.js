import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  connect() {
    document.getElementById("terminalInput").addEventListener('click', () => {
      document.getElementById("terminalInput").querySelector(".terminal-input").focus()
    })
  }

  clear_input() {
    this.inputTarget.textContent = ""
  }

  set_prompt(promptValue) {
    this.promptTarget.textContent = promptValue
  }

  show_error(errorMessage, fade = true) {
    this.errorTarget.textContent = errorMessage
    this.errorTarget.style.display = "inline-block"

    if(fade){
      setTimeout(() => {
        this.errorTarget.style.display = "none"
      }, 5000)
    }
  }
}
