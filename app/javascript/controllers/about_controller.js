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

      if(input_text == "TAVERN"){
        Turbo.visit("/tavern")
      } else if (input_text == "HOME") {
        Turbo.visit("/")
      } else {
        let error_text = '"' + input_text + '"!? You may go "HOME" or to the "TAVERN"'
        window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
      }
    }
  }
}
