import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.addEventListener('keydown', this.trigger_hotkey, false);
  }

  trigger_hotkey(e) {
    if (e.ctrlKey) {
      switch(e.key) {
        case 'h':
          document.location.href = '/'
          break;
        case 'r':
          document.location.href = "/signup"
          break;
        case 'l':
          if(confirm("Logout?")){
            document.location.href = "/logout"
          }
          break;
        case 't':
          document.location.href = "/tavern"
          break;
        case 'c':
          document.location.href = "/characters"
          break;
        case 'a':
          document.location.href = "/about"
          break;
      }
    }
  }
}
