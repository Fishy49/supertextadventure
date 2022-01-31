import { Controller } from "@hotwired/stimulus"
import { get, post } from '@rails/request.js'
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = [ "prompt", "input", "error" ]
  static values = {
    game: Number,
    gameUser: Number
  }

  observer = null

  connect(){
    this.channel = createConsumer().subscriptions.create(
      {
        channel: "GameUserIndicatorsChannel",
        id: this.gameUserValue,
      },
      {
        connected: this.initChannel.bind(this),
        disconnected: this._disconnected.bind(this),
        received: this._received.bind(this),
      }
    );

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

  _disconnected() {}

  _received(data) {
  }

  initChannel() {
    this.typingHandler = this.typing.bind(this)
    this.inputTarget.addEventListener('keydown', this.typingHandler)

    this.stoppedTyping = this.stoppedTyping.bind(this)
    this.inputTarget.addEventListener('blur', this.stoppedTyping)
  }

  typing() {
    // Don't broadcast if we're already typing
    if(!this.isTyping) {
      this.isTyping = true
      this.channel.perform('typing', { game_user_id: this.gameUserValue, typing: true } )
    }

    // Do this no matter what so it resets the timer
    this.startTypingTimer() 
  }

  stoppedTyping() {
    this.isTyping = false
    this.stopTypingTimer()
    this.channel.perform('typing', { game_user_id: this.gameUserValue, typing: false } )
  }

  startTypingTimer() {
    // Clear the old timer or it'll still fire after 10 seconds. We're effectively resetting the timer.
    this.stopTypingTimer()
    // No need to save a reference to bound function since we don't need to reference it to stop the timer.
    // After 10 seconds of not typing, don't consider the user to be typing
    this.typingTimeoutID = setTimeout(this.stoppedTyping.bind(this), 10000)
  }

  stopTypingTimer() {
    if(this.typingTimeoutID) {
      clearTimeout(this.typingTimeoutID)
    }
  }
}
