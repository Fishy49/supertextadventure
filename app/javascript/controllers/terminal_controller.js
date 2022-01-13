import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  connect() {
    // Focus on the contenteditable on a click anywhere in the container
    document.getElementById("terminalInput").addEventListener('click', () => {
      document.getElementById("terminalInput").querySelector(".terminal-input").focus()
      window.placeCaretAtEnd(this.inputTarget)
    })

    // To preserve the cursor illusion, prevent left-arrow from changing caret position.
    this.inputTarget.addEventListener('keydown', (e) => {
      if(e.keyCode == 37){
        e.preventDefault()
        window.placeCaretAtEnd(this.inputTarget)
      }
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
