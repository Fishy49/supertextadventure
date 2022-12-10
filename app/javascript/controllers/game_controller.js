import { Controller } from "@hotwired/stimulus"
import { get, post, patch } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static values = {
    id: Number,
    userId: String
  }

  observer = null
  messageToScrollIntoView = 'last'

  connect(){
    // If messages are being loaded from scrolling "up", we want the 
    // mutation observer to scroll the view to 0, otherwise all the way down
    document.addEventListener('turbo:before-stream-render', (event) => {
      if(event.detail.newStream.target == 'messages') {
        if(event.detail.newStream.action == 'prepend') {
          this.messageToScrollIntoView = 'first'
        } else {
          this.messageToScrollIntoView = 'last'
        }
      }
    });

    const targetNode = document.querySelector('.grid-in-message-container');
    let game_messages = targetNode.querySelectorAll('.game-message')
    game_messages[game_messages.length - 1].scrollIntoView();

    const callback = (mutationsList, observer) => {
      for(const mutation of mutationsList) {
        if (mutation.type === 'childList') {
          if(this.messageToScrollIntoView){
            targetNode.querySelector('.game-message').scrollIntoView();
          } else {
            game_messages[game_messages.length - 1].scrollIntoView();
          }
        }
      }
    }

    this.observer = new MutationObserver(callback)
    this.observer.observe(targetNode, { attributes: true, childList: true, subtree: true })
  }

  disconnect(){
    this.observer.disconnect()
  }

  is_host(){
    return this.userIdValue == "host"
  }

  capture_input(e) {

    if(e.keyCode == 13){
      e.preventDefault()

      let inputText = e.target.textContent.trim().toUpperCase()

      if(inputText === ""){ return false; }

      window.stimulus_controller("terminalInput", "terminal").clear_input()
      this.errorTarget.style.display = "none"

      if(inputText == "I" || inputText == "INV" || inputText == "INVENTORY") {

      } else {
        let game_payload = {
          message: {
            game_id: this.idValue,
            game_user_id: this.userIdValue,
            content: inputText
          }
        }
        post("/messages", { body: game_payload, responseKind: "turbo-stream" })
      }
    }
  }
}
