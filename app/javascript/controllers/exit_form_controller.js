import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]
  static values = { count: Number }

  connect() {
    // Initialize count from existing exits
    this.countValue = this.containerTarget.children.length
  }

  add(event) {
    event.preventDefault()

    const template = this.containerTarget.children[0].cloneNode(true)

    // Clear all input values
    template.querySelectorAll('input, select, textarea').forEach(input => {
      if (input.type === 'checkbox') {
        input.checked = false
        // Trigger change to hide advanced sections
        input.dispatchEvent(new Event('change'))
      } else {
        input.value = ''
      }
    })

    // Update index in names
    this.countValue++
    template.querySelectorAll('[name]').forEach(el => {
      const name = el.getAttribute('name')
      el.setAttribute('name', name.replace(/\[\d+\]/, `[${this.countValue}]`))
    })

    this.containerTarget.appendChild(template)
  }

  remove(event) {
    event.preventDefault()

    if (this.containerTarget.children.length > 1) {
      event.target.closest('.exit-fields').remove()
    }
  }

  toggleAdvanced(event) {
    const exitFields = event.target.closest('.exit-fields')
    const advancedSection = exitFields.querySelector('.exit-advanced')
    advancedSection.style.display = event.target.checked ? 'block' : 'none'
  }

  toggleUnlockFields(event) {
    const exitFields = event.target.closest('.exit-fields')
    const unlockType = event.target.value

    // Hide all conditional fields first
    exitFields.querySelectorAll('.unlock-field').forEach(field => {
      field.style.display = 'none'
    })

    // Show relevant fields based on unlock type
    if (unlockType === 'requires') {
      exitFields.querySelector('.unlock-requires').style.display = 'block'
    } else if (unlockType === 'requires_flag') {
      exitFields.querySelector('.unlock-flag').style.display = 'block'
    } else if (unlockType === 'use_item') {
      exitFields.querySelector('.unlock-use-item').style.display = 'block'
      exitFields.querySelector('.unlock-options').style.display = 'block'
    }
  }
}
