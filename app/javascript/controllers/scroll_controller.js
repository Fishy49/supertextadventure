import { Controller } from '@hotwired/stimulus'
import debounce from 'lodash.debounce';

export default class extends Controller {
  static targets = [ 'container', 'button' ]

  initialize(){
    this.load_messages = debounce(this.load_messages, 500).bind(this)
  }

  load_messages(){
    if(this.containerTarget.scrollTop < 500 && this.hasButtonTarget) {
      this.buttonTarget.click()
    }
  }
}
