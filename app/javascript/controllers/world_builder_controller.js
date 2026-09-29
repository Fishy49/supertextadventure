import { Controller } from "@hotwired/stimulus"
import { mountWorldBuilder } from "world_builder/builder"

// Hosts the world builder on /worlds/:id/edit. The world, the validation
// contract, and the sample worlds are embedded in the page as JSON script
// tags; saving PATCHes the world back through WorldsController#update.
export default class extends Controller {
  static values = { saveUrl: String, worldId: Number }

  connect() {
    const read = id => JSON.parse(document.getElementById(id).textContent)
    this.builder = mountWorldBuilder(this.element, {
      mode: "rails",
      world: read("wb-world"),
      contract: { schema: read("wb-schema"), refs: read("wb-refs") },
      samples: read("wb-samples"),
      storageKey: `sta-wb-draft-world-${this.worldIdValue}`,
      save: (json, world) => this.save(json, world)
    })
  }

  async save(json, world) {
    const body = new FormData()
    body.append("world[world_data]", json)
    body.append("world[name]", world.meta.name || "")
    body.append("world[description]", world.meta.description || "")
    const headers = { Accept: "application/json" }
    const csrf = document.querySelector("meta[name='csrf-token']")
    if (csrf) headers["X-CSRF-Token"] = csrf.content
    const response = await fetch(this.saveUrlValue, { method: "PATCH", body, headers })
    const data = await response.json().catch(() => ({}))
    if (response.ok) return { ok: true }
    return { ok: false, errors: data.errors || [`Save failed (${response.status})`] }
  }
}
