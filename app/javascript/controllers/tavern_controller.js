import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  capture_input(e) {
    if(e.keyCode == 13){
      let input_text = e.target.textContent.trim().toUpperCase()

      if(input_text === ""){
        e.preventDefault();
        return false;
      }

      window.stimulus_controller("terminalInput", "terminal").clear_input();
      this.errorTarget.style.display = "none"

      if(input_text == "LIST GAMES"){
        Turbo.visit("/tavern/games")
      } else if (input_text == "START GAME") {
        Turbo.visit("/tavern/new-game")
      } else {
        let error_text = 'What Doth "' + input_text + '" Imply!?'
        window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
      }
    }
  }
}
