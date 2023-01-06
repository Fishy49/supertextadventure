import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String
  }

  to_clipboard(e) {
    navigator.clipboard.writeText(this.textValue);
    let el = e.currentTarget;
    el.innerHTML = "Copied!";
    setTimeout( () => { el.innerHTML = "Copy"; }, 1500 );
  }
}
