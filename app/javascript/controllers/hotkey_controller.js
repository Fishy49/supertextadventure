import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  initialize() {
    this.path = '';
  }

  visitPath() {
    if(this.path == '/logout'){
      if(confirm('Logout?')){
        Turbo.visit('/logout')
      }
    } else if(this.path == '/setup_tokens' && document.getElementById('owner-invite-hotkey')) {
      Turbo.visit('/setup_tokens')
    } else {
      Turbo.visit(this.path);
    }
  }

  triggerHotkeyFromKeydown(e) {
    if (!e.altKey) return;

    e.preventDefault();
    e.stopPropagation();

    let hotkey_element = document.getElementById(`hotkey-${e.key}`);

    if(hotkey_element){
      this.path = hotkey_element.getAttribute('data-hotkey-path-param');
      this.visitPath();
    }

  }

  triggerHotkey(e) {
    if (e.params == {}) return;

    this.path = e.params.path;
    this.visitPath();
  }
}
