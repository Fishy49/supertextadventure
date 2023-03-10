import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = [ "healthForm" ]

	static values = { muted: Boolean, id: Number }

	health_form() {
		if(this.healthFormTarget.classList.contains('hidden')){
			this.healthFormTarget.classList.remove("hidden");
		}
	}

	close_health_form(e) {
		e.stopPropagation();
		this.healthFormTarget.classList.add("hidden");
	}
}
