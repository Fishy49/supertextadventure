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
          let error_text = 'I know not what "' + input_text + '" means!'
          window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
        }
      }
    })
  }
}
