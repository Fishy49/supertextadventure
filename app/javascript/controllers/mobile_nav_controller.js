import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "sidebar"]

  toggleDrawer() {
    if (this.hasDrawerTarget) {
      const drawer = this.drawerTarget
      const isOpen = !drawer.classList.contains("translate-y-full")
      if (isOpen) {
        drawer.classList.add("translate-y-full")
        drawer.classList.remove("translate-y-0")
      } else {
        drawer.classList.remove("translate-y-full")
        drawer.classList.add("translate-y-0")
      }
    }
  }

  toggleSidebar() {
    const sidebarPanel = document.getElementById("sidebar-panel")
    if (!sidebarPanel) return

    const isVisible = !sidebarPanel.classList.contains("hidden")
    if (isVisible) {
      sidebarPanel.classList.add("hidden")
      sidebarPanel.classList.remove("fixed", "inset-y-0", "right-0", "w-3/4", "z-30", "border-l-2",
        "border-terminal-green", "bg-stone-800", "overflow-y-auto", "px-3", "translate-x-0",
        "transition-transform", "duration-300")
    } else {
      sidebarPanel.classList.remove("hidden")
      sidebarPanel.classList.add("fixed", "inset-y-0", "right-0", "w-3/4", "z-30", "bg-stone-800",
        "overflow-y-auto", "px-3", "transition-transform", "duration-300")
    }

    // Close nav drawer if open
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.add("translate-y-full")
      this.drawerTarget.classList.remove("translate-y-0")
    }
  }

  closeAll() {
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.add("translate-y-full")
      this.drawerTarget.classList.remove("translate-y-0")
    }

    const sidebarPanel = document.getElementById("sidebar-panel")
    if (sidebarPanel) {
      sidebarPanel.classList.add("hidden")
      sidebarPanel.classList.remove("fixed", "inset-y-0", "right-0", "w-3/4", "z-30")
    }
  }
}
