import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  get drawer() {
    return document.querySelector("[data-mobile-nav-target='drawer']")
  }

  toggleDrawer() {
    const drawer = this.drawer
    if (!drawer) return

    const isOpen = !drawer.classList.contains("translate-y-full")
    if (isOpen) {
      drawer.classList.add("translate-y-full")
      drawer.classList.remove("translate-y-0")
    } else {
      drawer.classList.remove("translate-y-full")
      drawer.classList.add("translate-y-0")
    }
  }

  toggleSidebar() {
    const sidebarPanel = document.getElementById("sidebar-panel")
    if (!sidebarPanel) return

    const isVisible = !sidebarPanel.classList.contains("hidden")
    if (isVisible) {
      sidebarPanel.classList.add("hidden")
      sidebarPanel.classList.remove("fixed", "inset-y-0", "right-0", "w-3/4", "z-30",
        "bg-stone-800", "overflow-y-auto", "px-3", "transition-transform", "duration-300")
    } else {
      sidebarPanel.classList.remove("hidden")
      sidebarPanel.classList.add("fixed", "inset-y-0", "right-0", "w-3/4", "z-30", "bg-stone-800",
        "overflow-y-auto", "px-3", "transition-transform", "duration-300")
    }

    // Close nav drawer if open
    const drawer = this.drawer
    if (drawer) {
      drawer.classList.add("translate-y-full")
      drawer.classList.remove("translate-y-0")
    }
  }

  closeAll() {
    const drawer = this.drawer
    if (drawer) {
      drawer.classList.add("translate-y-full")
      drawer.classList.remove("translate-y-0")
    }

    const sidebarPanel = document.getElementById("sidebar-panel")
    if (sidebarPanel) {
      sidebarPanel.classList.add("hidden")
      sidebarPanel.classList.remove("fixed", "inset-y-0", "right-0", "w-3/4", "z-30")
    }
  }
}
