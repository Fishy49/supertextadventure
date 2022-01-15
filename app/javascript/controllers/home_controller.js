import { Controller } from "@hotwired/stimulus"

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

      if(input_text.includes("TAVERN") || input_text.includes("NORTH")){
        Turbo.visit("/tavern")
      } else if(input_text == "GO") {
        window.stimulus_controller("terminalInput", "terminal").show_error('"Go" Where?', false)
      } else {
        let error_text = 'Perhaps Ye Should Just Go to Yon "TAVERN"...'
        window.stimulus_controller("terminalInput", "terminal").show_error(error_text, false)
      }
    }
  }
}
