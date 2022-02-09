import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'

export default class extends Controller {
  connect() {
    window.addEventListener('keydown', this.trigger_hotkey, false);
  }

  trigger_hotkey(e) {
    if (e.ctrlKey) {
      switch(e.key) {
        case 'h':
          Turbo.visit('/')
          break;
        case 'r':
          Turbo.visit('/signup')
          break;
        case 'l':
          if(confirm('Logout?')){
            Turbo.visit('/logout')
          }
          break;
        case 't':
          Turbo.visit('/tavern')
          break;
        case 'c':
          Turbo.visit('/characters')
          break;
        case 'a':
          Turbo.visit('/about')
          break;
      }
    }
  }
}
