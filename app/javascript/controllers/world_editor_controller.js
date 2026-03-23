import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "jsonInput", "form", "worldDataField", "status"]

  async connect() {
    await this.initializeCodeMirror()
    this.setupJsonUpdateObserver()
  }

  setupJsonUpdateObserver() {
    // Watch for changes to the hidden JSON update element
    const targetNode = document.getElementById('editor-json-update')
    if (!targetNode) return

    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList' || mutation.type === 'characterData') {
          const jsonString = targetNode.textContent
          if (jsonString && jsonString.trim()) {
            this.setEditorValue(jsonString)
            this.updateStatus("Updated from server")
            setTimeout(() => this.updateStatus("Ready"), 2000)
          }
        }
      })
    })

    this.observer.observe(targetNode, {
      childList: true,
      characterData: true,
      subtree: true
    })
  }

  async initializeCodeMirror() {
    try {
      // Import CodeMirror 6 and extensions
      const { EditorView, basicSetup } = await import("codemirror")
      const { json } = await import("@codemirror/lang-json")
      const { EditorState } = await import("@codemirror/state")
      const { tags } = await import("@lezer/highlight")
      const { HighlightStyle } = await import("@codemirror/language")
      const { syntaxHighlighting } = await import("@codemirror/language")

      const myHighlightStyle = HighlightStyle.define([
        {tag: tags.string, color: "#2203ff"},
        {tag: tags.comment, color: "#000", fontStyle: "italic"}
      ])

      // Create the editor state with all extensions
      const startState = EditorState.create({
        doc: this.jsonInputTarget.value,
        extensions: [
          basicSetup,
          syntaxHighlighting(myHighlightStyle),
          EditorView.lineWrapping,
          json(),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) {
              this.updateStatus("Modified")
              this.dispatchPreviewUpdate()
            }
          }),
          EditorView.theme({
            "&": {
              height: "100%",
              backgroundColor: "#fff",
              color: "#000"
            },
            ".cm-content": {
              caretColor: "#22c55e",
              fontFamily: "'Courier New', monospace",
              fontSize: "14px",
              fontWeight: "bold"
            },
            ".cm-gutters": {
              backgroundColor: "#292524",
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

      // Create and mount the editor
      this.editorView = new EditorView({
        state: startState,
        parent: this.editorTarget
      })

      this.updateStatus("Ready")
    } catch (error) {
      console.error("Failed to initialize CodeMirror:", error)
      this.updateStatus("Editor error")
      this.useFallbackEditor()
    }
  }

  useFallbackEditor() {
    // Fallback to simple textarea if CodeMirror fails
    this.editorTarget.innerHTML = `
      <textarea
        class="json-editor-textarea w-full h-full bg-stone-900 text-terminal-green p-4 font-mono text-sm focus:outline-none terminal-scrollbars"
        style="resize: none; tab-size: 2;"
        spellcheck="false"
      >${this.jsonInputTarget.value}</textarea>
    `
    this.textarea = this.editorTarget.querySelector("textarea")
    this.textarea.addEventListener("input", () => {
      this.updateStatus("Modified")
      this.dispatchPreviewUpdate()
    })
    this.fallbackMode = true
  }

  dispatchPreviewUpdate() {
    const json = this.getEditorValue()
    const event = new CustomEvent("world-data-changed", {
      detail: { json }
    })
    window.dispatchEvent(event)
  }

  getEditorValue() {
    if (this.fallbackMode) {
      return this.textarea.value
    }
    return this.editorView.state.doc.toString()
  }

  setEditorValue(value) {
    if (this.fallbackMode) {
      this.textarea.value = value
    } else {
      this.editorView.dispatch({
        changes: {
          from: 0,
          to: this.editorView.state.doc.length,
          insert: value
        }
      })
    }
  }

  formatJson() {
    try {
      const jsonString = this.getEditorValue()
      const parsed = JSON.parse(jsonString)
      const formatted = JSON.stringify(parsed, null, 2)
      this.setEditorValue(formatted)
      this.updateStatus("JSON formatted")
      this.dispatchPreviewUpdate()
    } catch (error) {
      this.updateStatus("Invalid JSON")
      alert("Invalid JSON: " + error.message)
    }
  }

  async saveWorld(event) {
    event.preventDefault()

    try {
      const jsonString = this.getEditorValue()
      const parsed = JSON.parse(jsonString)

      // Update the hidden field
      this.worldDataFieldTarget.value = jsonString

      // Get the form and submit via fetch
      const form = this.formTarget
      const url = form.action
      const formData = new FormData(form)

      this.updateStatus("Saving...")

      const response = await fetch(url, {
        method: "PATCH",
        body: formData,
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Accept": "application/json"
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.updateStatus("Saved successfully")
        setTimeout(() => this.updateStatus("Ready"), 2000)
      } else {
        this.updateStatus("Save failed")
        alert("Failed to save: " + (data.errors || ["Unknown error"]).join(", "))
      }
    } catch (error) {
      this.updateStatus("Invalid JSON")
      alert("Invalid JSON: " + error.message)
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.editorView) {
      this.editorView.destroy()
    }
  }
}
