import { Controller } from "@hotwired/stimulus"
import { get, post } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static values = {
    game: Number,
    gameUser: Number
  }

  observer = null

  connect(){
    const targetNode = document.querySelector('.game-message-area');
    targetNode.scrollTo(0, 100000)

    const callback = (mutationsList, observer) => {
      for(const mutation of mutationsList) {
        if (mutation.type === 'childList') { targetNode.scrollTo(0, 100000) }
      }
    }

    this.observer = new MutationObserver(callback)
    this.observer.observe(targetNode, { attributes: true, childList: true, subtree: true })
  }

  disconnect(){
    this.observer.disconnect()
  }

  capture_input(e) {
    if(e.keyCode == 13){
      e.preventDefault();

      let inputText = e.target.textContent.trim().toUpperCase()

      if(inputText === ""){ return false; }

      window.stimulus_controller("terminalInput", "terminal").clear_input()
      this.errorTarget.style.display = "none"

      if(inputText == "I" || inputText == "INV" || inputText == "INVENTORY") {
        
      } else {
        let game_payload = {
          message: {
            game_id: this.gameValue,
            game_user_id: this.gameUserValue,
            content: inputText
          }
        }
      }

      post("/messages", { body: game_payload, responseKind: "turbo-stream" })
    }
  }
}
