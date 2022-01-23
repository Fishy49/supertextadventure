import { Controller } from "@hotwired/stimulus"
import { get, post } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static values = {
    user: Number,
    game: Number
  }

  capture_input(e) {
    if(e.keyCode == 13){
      e.preventDefault();

      let inputText = e.target.textContent.trim().toUpperCase()

      if(inputText === ""){
        return false;
      }

      window.stimulus_controller("terminalInput", "terminal").clear_input()
      this.errorTarget.style.display = "none"

      let game_payload = {
        message: {
          game_id: 1,
          user_id: 1,
          content: inputText
        }
      }

      post("/messages/create", { body: game_payload }, { responseKind: "turbo-stream" })
    }
  }
}
