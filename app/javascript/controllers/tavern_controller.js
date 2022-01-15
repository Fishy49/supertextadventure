import { Controller } from "@hotwired/stimulus"
import { get } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  capture_input(e) {
    if(e.keyCode == 13){
      e.preventDefault();
      
      let input_text = e.target.textContent.trim().toUpperCase()

      if(input_text === ""){
        return false;
      }

      window.stimulus_controller("terminalInput", "terminal").clear_input()
      this.errorTarget.style.display = "none"

      if(input_text == "LIST GAMES"){
        get("/games", { responseKind: "turbo-stream" })
      } else if (input_text == "START GAME") {
        get("/games/new", { responseKind: "turbo-stream" })
      } else {
        let error_text = 'What Doth "' + input_text + '" Imply!?'
        window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
      }
    }
  }
}
