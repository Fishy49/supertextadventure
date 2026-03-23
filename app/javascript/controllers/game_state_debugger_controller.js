import { Controller } from "@hotwired/stimulus"
import { EditorView, basicSetup } from "codemirror"
import { json } from "@codemirror/lang-json"
import { EditorState } from "@codemirror/state"
import { tags } from "@lezer/highlight"
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language"

export default class extends Controller {
  static targets = ["panel", "editor", "saveButton"]
  static values = {
    gameId: String
  }

  connect() {
    this.editorView = null
  }

  async toggle() {
    if (!this.panelTarget.classList.contains('translate-x-full')) {
      this.close()
    } else {
      await this.open()
    }
  }

  async open() {
    // Fetch fresh game state
    const response = await fetch(`/games/${this.gameIdValue}/debug_state`)
    const data = await response.json()

    // Clear and rebuild editor
    this.editorTarget.innerHTML = ''

    // Terminal-style syntax highlighting (matching world editor)
    const terminalHighlightStyle = HighlightStyle.define([
      { tag: tags.string, color: "#84bdff" },
      { tag: tags.number, color: "#22c55e" },
      { tag: tags.bool, color: "#22c55e" },
      { tag: tags.null, color: "#666" },
      { tag: tags.keyword, color: "#22c55e" },
      { tag: tags.propertyName, color: "#22c55e" },
      { tag: tags.comment, color: "#666", fontStyle: "italic" }
    ])

    const startState = EditorState.create({
      doc: JSON.stringify(data.state, null, 2),
      extensions: [
        basicSetup,
        syntaxHighlighting(terminalHighlightStyle),
        EditorView.lineWrapping,
        json(),
        EditorView.theme({
          "&": {
            height: "100%",
            backgroundColor: "#292524",
            color: "#22c55e"
          },
          ".cm-content": {
            caretColor: "#22c55e",
            fontFamily: "'Courier New', monospace",
            fontSize: "14px",
            fontWeight: "bold"
          },
          ".cm-gutters": {
            backgroundColor: "#1c1917",
            color: "#22c55e",
            border: "none",
            borderRight: "1px solid #22c55e",
            fontSize: "14px",
            fontFamily: "'Courier New', monospace"
          },
          ".cm-activeLineGutter": {
            backgroundColor: "#292524"
          },
          ".cm-foldGutter": {
            width: "16px"
          },
          ".cm-foldPlaceholder": {
            backgroundColor: "#44403c",
            border: "1px solid #22c55e",
            color: "#22c55e"
          },
          ".cm-selectionBackground, ::selection": {
            backgroundColor: "rgba(34, 197, 94, 0.2) !important"
          },
          ".cm-focused .cm-selectionBackground": {
            backgroundColor: "rgba(34, 197, 94, 0.3) !important"
          },
          ".cm-activeLine": {
            backgroundColor: "rgba(34, 197, 94, 0.1)"
          },
          ".cm-cursor": {
            borderLeftColor: "#22c55e"
          }
        })
      ]
    })

    this.editorView = new EditorView({
      state: startState,
      parent: this.editorTarget
    })

    // Slide in from right
    this.panelTarget.classList.remove('translate-x-full')
  }

  close() {
    // Slide out to right
    this.panelTarget.classList.add('translate-x-full')
    if (this.editorView) {
      this.editorView.destroy()
      this.editorView = null
    }
  }

  async save() {
    const jsonContent = this.editorView.state.doc.toString()
    
    try {
      const parsedJson = JSON.parse(jsonContent)
      
      const response = await fetch(`/games/${this.gameIdValue}/debug_state`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ state: parsedJson })
      })
      
      if (response.ok) {
        // Flash success message
        this.showMessage('Game state saved!', 'success')
        // Reload the game view to show updated state
        setTimeout(() => window.location.reload(), 500)
      } else {
        this.showMessage('Failed to save game state', 'error')
      }
    } catch (e) {
      this.showMessage('Invalid JSON: ' + e.message, 'error')
    }
  }

  showMessage(text, type) {
    const message = document.createElement('div')
    message.className = `debug-message ${type}`
    message.textContent = text
    this.panelTarget.appendChild(message)
    setTimeout(() => message.remove(), 3000)
  }
}
