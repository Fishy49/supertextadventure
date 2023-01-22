import { Controller } from "@hotwired/stimulus"
import { get, post } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]

  capture_input(e) {
    if(e.keyCode == 13){
      e.preventDefault();

      let inputText = e.target.textContent.trim().toUpperCase()

      if(inputText === ""){
        return false;
      }

      window.stimulus_controller("terminalInput", "terminal").clear_input()
      this.errorTarget.style.display = "none"

      let getMap = {
        "LIST TABLES": "/games/list",
        "NEW TABLE": "/games/new",
        "LIST FRIENDS": "/friends"
      }

      if(getMap.hasOwnProperty(inputText)){
        get(getMap[inputText], { responseKind: "turbo-stream" })
      
      } else if (inputText.startsWith("MAKE FRIEND")) {
        let username = this.extract_argument(inputText, "MAKE FRIEND")

        if(!username){
          this.show_error("Try typing a username!", false)
        } else {
          post("/friends/create", { body: { username: username }, responseKind: "turbo-stream" })
        }

      } else if (inputText.startsWith("JOIN TABLE")) {
        let tableNumber = this.extract_argument(inputText, "JOIN TABLE")
        let gameListElement = document.getElementById('table-join-element-' + tableNumber)

        if(!gameListElement){
          let error_text = 'Could not find a table for #' + tableNumber + '!'
          this.show_error(error_text, false)
        } else {
          get('/games/' + gameListElement.dataset.gameId + '/lobby', { responseKind: "turbo-stream" })
        }
      } else if (inputText.startsWith("JOIN GAME")) {
        let gameJoinButton = document.getElementById('game-join-element')

        if(!gameJoinButton){
          let error_text = 'JOIN a TABLE first!'
          this.show_error(error_text, false)
        } else {
          Turbo.visit('/games/' + gameJoinButton.dataset.uuid, { frame: "_top" })
        }
      } else {
        let error_text = 'What Doth "' + inputText + '" Imply!?'
        this.show_error(error_text, false)
      }
    }
  }

  extract_argument(text, command){
    return text.replace(command, "").trim().replace("#", "")
  }

  show_error(text, fade){
    window.stimulus_controller("terminalInput", "terminal").show_error(text, fade)
  }
}
