import { Controller } from "@hotwired/stimulus"
import { get, post, patch } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static outlets = [ "game-user" ]
  static values = {
    id: Number,
    userId: String
  }

  observer = null
  scrollPosition = 'last'
  message_count = 0
  first_load = true

  connect(){
    const targetNode = document.querySelector('.grid-in-message-container');
    let game_messages = targetNode.querySelectorAll('.game-message')

    this.message_count = game_messages.length
    if(this.message_count > 0) {
      targetNode.scrollTo(0, targetNode.scrollHeight)
    }

    setTimeout(() => {      
      document.getElementById('loading-modal').remove();
      document.getElementById('message-content-wrapper').classList.remove('invisible');
    }, 500)

    // If messages are being loaded from scrolling "up", we want the 
    // mutation observer to scroll the view to 0, otherwise all the way down
    document.addEventListener('turbo:before-stream-render', (event) => {
      if(event.detail.newStream.target == 'messages' || event.detail.newStream.target.indexOf("message_") === 0) {
        if(event.detail.newStream.action == 'prepend') {
          this.scrollPosition = document.getElementById('game-messages').getBoundingClientRect().height
        } else {
          this.scrollPosition = 'last'
        }
      }
    });

    const callback = (mutationsList, observer) => {
      for(const mutation of mutationsList) {
        if (mutation.type === 'childList' && targetNode.querySelectorAll('.game-message').length != this.message_count) {
          this.message_count = targetNode.querySelectorAll('.game-message').length
          if(this.scrollPosition == 'last' && targetNode.querySelectorAll('.game-message').length > 0){
            targetNode.scrollTo(0, targetNode.scrollHeight)
          } else if(!this.first_load) {
            this.first_load = false
            let calculated_scroll = (this.scrollPosition - document.getElementById('game-messages').getBoundingClientRect().height) * -1
            targetNode.scrollTo(0, (calculated_scroll));
          }
        } else if (mutation.type == 'childList' && this.scrollPosition == 'last') {
          targetNode.scrollTo(0, targetNode.scrollHeight)
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

      let error_for_mute_flag = false;

      if(!this.is_host()){
        this.gameUserOutlets.forEach(player => {
          if(player.idValue.toString() == this.userIdValue && player.mutedValue == true){
            error_for_mute_flag = true;
          }
        })
      }

      if(error_for_mute_flag){
        this.show_error("You are muted!", true)
        return false;
      }

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

  show_error(text, fade){
    window.stimulus_controller("terminalInput", "terminal").show_error(text, fade)
  }
}
