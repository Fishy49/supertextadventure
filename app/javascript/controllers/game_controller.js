import { Controller } from "stimulus"
import { cspNonce } from '@rails/ujs';
import createChannel from "cables/cable";

export default class extends Controller {
  static targets = [ "game" ]

  initialize() {
    let gameController = this;
    this.gameChannel = createChannel(
      { 
        channel: "GameChannel",
        game_id: document.getElementById('game').getAttribute('data-game-id'),
        connected() {
          gameController.listen()
        },
        received(data) {
          let script = document.createElement('script');
          script.setAttribute('nonce', cspNonce());
          script.text = response;
          document.head.appendChild(script).parentNode.removeChild(script);
        }
      }
    );
  }

  connect() {
    this.listen()
  }

  disconnect() {
    this.gameChannel.perform('unfollow')
  }

  listen() {
    if (this.gameChannel) {
      this.gameChannel.perform('follow')
    }
  }
}
