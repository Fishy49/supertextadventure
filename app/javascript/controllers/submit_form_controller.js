import { Controller } from "@hotwired/stimulus"
import Rails from "@rails/ujs"

export default class extends Controller {
  static targets = [ "form", "field" ]

  check_submit(event) {
    if (event.keyCode == 13 && !event.shiftKey && this.fieldTarget.value !== '') {
      event.preventDefault();

      Rails.fire(this.formTarget, 'submit')
    }
  }
}
