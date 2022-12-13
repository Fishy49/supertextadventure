import { Controller } from '@hotwired/stimulus'

export default class extends Controller {

  html(event){
    event.target.setAttribute("disabled", "")
    event.target.innerHTML = event.params.html
  }
}
