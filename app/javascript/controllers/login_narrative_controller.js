import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  static NARRATIVES = [
    "> look around",
    "You stand at the entrance to a vast dungeon.",
    "Torchlight flickers against damp stone walls.",
    "> go north",
    "A narrow corridor stretches into darkness.",
    "You hear the distant sound of dripping water.",
    "> examine door",
    "An iron-bound oak door blocks your path.",
    "Strange runes glow faintly on its surface.",
    "> take torch",
    "You lift the torch from its sconce.",
    "Shadows dance as the flame sputters.",
    "> inventory",
    "You carry: a rusty sword, a torch, a leather pouch.",
    "> open pouch",
    "Inside you find a crumpled map and three coins.",
    "> read map",
    "The map shows winding passages beneath a castle.",
    "An X marks a chamber deep underground.",
    "> go east",
    "The passage opens into a cavernous hall.",
    "Pillars of carved stone line the walls.",
    "> listen",
    "You hear a faint growl echoing from below.",
    "> examine runes",
    "The runes pulse with a faint green light.",
    "They spell a warning in an ancient tongue.",
    "> go down",
    "Stone steps spiral downward into the earth.",
    "The air grows cold and still.",
  ]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.showStaticNarrative()
      return
    }

    this.lineIndex = 0
    this.startNarrative()
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  startNarrative() {
    this.addLine()
    this.timer = setInterval(() => this.addLine(), 3000)
  }

  addLine() {
    const lines = this.constructor.NARRATIVES
    if (this.lineIndex >= lines.length) {
      this.lineIndex = 0
      this.outputTarget.innerHTML = ""
    }

    const el = document.createElement("div")
    el.classList.add("login-narrative-line", "text-terminal-green", "text-xs")
    el.textContent = lines[this.lineIndex]
    this.outputTarget.appendChild(el)
    this.lineIndex++

    while (this.outputTarget.children.length > 15) {
      this.outputTarget.removeChild(this.outputTarget.firstChild)
    }
  }

  showStaticNarrative() {
    const lines = this.constructor.NARRATIVES.slice(0, 8)
    lines.forEach(line => {
      const el = document.createElement("div")
      el.classList.add("login-narrative-line", "text-terminal-green", "text-xs")
      el.textContent = line
      this.outputTarget.appendChild(el)
    })
  }
}
