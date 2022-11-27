import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  last_input = ""

  connect() {
    // Focus on the contenteditable on a click anywhere in the container and place caret at end
    document.getElementById("terminalInput").addEventListener('click', () => {
      document.getElementById("terminalInput").querySelector(".terminal-input").focus()
      window.placeCaretAtEnd(this.inputTarget)
    })

    this.inputTarget.focus()
  }

  default_input_handling(e){
    // On "left" arrow, we want to snap to the end of anything typed
    if(e.keyCode == 37){
      e.preventDefault()
      window.placeCaretAtEnd(this.inputTarget)
    }

    // On "up" arrow, retrieve the last entry if it exists
    if(e.keyCode == 38){
      if(this.last_input){
        e.preventDefault()
        e.target.textContent = this.last_input
        window.placeCaretAtEnd(this.inputTarget)
      }
    }
  }

  save_input(input){
    this.last_input = input
  }

  clear_input() {
    this.save_input(this.inputTarget.textContent)
    this.inputTarget.textContent = ""
  }

  set_prompt(promptValue) {
    this.promptTarget.textContent = promptValue
  }

  show_error(errorMessage, fade = true) {
    this.errorTarget.textContent = errorMessage
    this.errorTarget.style.display = "inline-block"

    window.beep(15, 100, 250)

    if(fade){
      setTimeout(() => {
        this.errorTarget.style.display = "none"
      }, 5000)
    }
  }
}
