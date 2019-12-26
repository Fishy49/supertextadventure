import { Controller } from "stimulus"
import { cspNonce } from '@rails/ujs';
import createChannel from "cables/cable";

export default class extends Controller {
  static targets = [ "game_message" ]

  initialize() {
    let GameMessageController = this;
    this.GameMessageChannel = createChannel(
      { 
        channel: "GameMessageChannel",
        game_id: document.getElementById('game').getAttribute('data-game-id')
      },
      {
        connected() {
          GameMessageController.listen()
        },
        received(data) {
          let script = document.createElement('script');
          script.setAttribute('nonce', cspNonce());
          script.text = data.script;
          document.head.appendChild(script).parentNode.removeChild(script);
        }
      }
    );
  }

  connect() {
    this.listen()
  }

  disconnect() {
    this.GameMessageChannel.perform('unfollow')
  }

  listen() {
    if (this.GameMessageChannel) {
      this.GameMessageChannel.perform('follow')
    }
  }
}
