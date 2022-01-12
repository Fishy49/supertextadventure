import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  connect() {
    this.inputTarget.addEventListener('keydown', (e) => {
      if(e.keyCode == 13){
        let input_text = e.target.textContent.trim()

        window.stimulus_controller("terminalInput", "terminal").clear_input();
        this.errorTarget.style.display = "none"

        if(input_text == "LIST GAMES"){

        } else if (input_text == "START GAME") {

        } else {
          window.beep(15, 100, 250)
          let error_text = 'What Doth "' + input_text + '" Imply!?'
          window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
        }
      }
    })
  }
}
