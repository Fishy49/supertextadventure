import { Controller } from "@hotwired/stimulus"
import { get, post, patch } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static values = {
    game: Number,
    gameUser: String
  }

  observer = null

  connect(){

    patch(this.patch_url('/online'))
    this.onlineLoop()

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
    patch(this.patch_url('/offline'))
    clearTimeout(this.onlineTimeout)
  }

  is_host(){
    return this.gameUserValue == "host"
  }

  patch_url(path = ''){
    let url
    if(this.is_host()){
      url = `/games/${this.gameValue}/host`
    } else {
      url = `/game_users/${this.gameUserValue}`
    }
    return url + path
  }

  capture_input(e) {

    if(e.keyCode == 13){
      e.preventDefault()

      this.stoppedTyping()

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
    } else {
      this.typing()
    }
  }

  onlineLoop() {
    this.onlineTimeout = setTimeout(() => { 
      patch(this.patch_url('/online'))
      this.onlineLoop()
    }, 5000)
  }

  typing() {
    // Don't broadcast if we're already typing
    if(!this.isTyping) {
      this.isTyping = true
      patch(this.patch_url('/typing'))
    }

    // Do this no matter what so it resets the timer
    this.startTypingTimer() 
  }

  stoppedTyping() {
    this.isTyping = false
    this.stopTypingTimer()
    patch(this.patch_url('/stop-typing'))
  }

  startTypingTimer() {
    // Clear the old timer or it'll still fire after 5 seconds. We're effectively resetting the timer.
    this.stopTypingTimer()
    // No need to save a reference to bound function since we don't need to reference it to stop the timer.
    // After 10 seconds of not typing, don't consider the user to be typing
    this.typingTimeoutID = setTimeout(this.stoppedTyping.bind(this), 5000)
  }

  stopTypingTimer() {
    if(this.typingTimeoutID) {
      clearTimeout(this.typingTimeoutID)
    }
  }
}
