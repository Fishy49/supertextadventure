import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: String, default: "inventory" } }

  connect(){
    this.render()
  }

  switch({ params }){
    if(!params.name){ return }
    this.activeValue = params.name
  }

  activeValueChanged(){
    this.render()
  }

  render(){
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.sidebarTabsNameParam === this.activeValue
      tab.classList.toggle("border-terminal-green", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("opacity-50", !active)
      tab.setAttribute("aria-selected", active.toString())
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.sidebarTabsName === this.activeValue
      panel.classList.toggle("hidden", !active)
    })
  }
}
