import { Controller } from '@hotwired/stimulus'
import { get } from '@rails/request.js'

export default class extends Controller {
	static targets = [
		'form',
		'currentContextInput',
		'modal',
		'promptInput',
		'lengthInput',
		'styleInput',
		'loadingIndicator'
	]

	open_modal() {
		this.formTarget.classList.remove('hidden')
		this.loadingIndicatorTarget.classList.add('hidden')

		if(this.modalTarget.classList.contains('hidden')){
			this.modalTarget.classList.remove('hidden');
		}
	}

	close_modal(e) {
		e.stopPropagation();
		this.modalTarget.classList.add('hidden');
	}

	get_text(e) {
		let formData = {
			prompt: this.promptInputTarget.value,
			length: this.lengthInputTargets.find((el) => { return el.checked  }).value,
			style: this.styleInputTargets.find((el) => { return el.checked  }).value,
		}

		this.formTarget.classList.add('hidden')
		this.loadingIndicatorTarget.classList.remove('hidden')

		const response = get('/generate-text', { query: formData })
		response.then((r) => {
			if(r.ok){
				r.json.then((j) => {
					document.getElementById('game_current_context').value = j.generated_text.trim("\n")
					this.close_modal(e)
				})
			} else {
				alert("Oh mine stars. That be broke.")
			}
		})
	}
}
