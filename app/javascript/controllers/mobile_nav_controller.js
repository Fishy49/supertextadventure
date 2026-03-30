import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  get drawer() {
    return document.querySelector("[data-mobile-nav-target='drawer']")
  }

  get backdrop() {
    return document.getElementById("mobile-sidebar-backdrop")
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

    this.syncButtonState()
  }

  toggleSidebar() {
    const sidebarPanel = document.getElementById("sidebar-panel")
    if (!sidebarPanel) return

    const isVisible = !sidebarPanel.classList.contains("hidden")
    if (isVisible) {
      this.closeSidebar()
    } else {
      this.openSidebar()
    }
  }

  openSidebar() {
    const sidebarPanel = document.getElementById("sidebar-panel")
    if (!sidebarPanel || !sidebarPanel.classList.contains("hidden")) return

    sidebarPanel.classList.remove("hidden")
    sidebarPanel.classList.add("fixed", "inset-y-0", "right-0", "w-3/4", "z-30", "bg-stone-800",
      "overflow-y-auto", "px-3", "transition-transform", "duration-300")

    const backdrop = this.backdrop
    if (backdrop) backdrop.classList.remove("hidden")

    // Close nav drawer if open
    const drawer = this.drawer
    if (drawer) {
      drawer.classList.add("translate-y-full")
      drawer.classList.remove("translate-y-0")
    }

    this.syncButtonState()
  }

  closeSidebar() {
    const sidebarPanel = document.getElementById("sidebar-panel")
    if (!sidebarPanel) return

    sidebarPanel.classList.add("hidden")
    sidebarPanel.classList.remove("fixed", "inset-y-0", "right-0", "w-3/4", "z-30",
      "bg-stone-800", "overflow-y-auto", "px-3", "transition-transform", "duration-300")

    const backdrop = this.backdrop
    if (backdrop) backdrop.classList.add("hidden")

    this.syncButtonState()
  }

  closeAll() {
    const drawer = this.drawer
    if (drawer) {
      drawer.classList.add("translate-y-full")
      drawer.classList.remove("translate-y-0")
    }

    this.closeSidebar()
  }

  syncButtonState() {
    const drawer = this.drawer
    const drawerBtn = document.getElementById("mobile-drawer-btn")
    if (drawerBtn && drawer) {
      const drawerOpen = !drawer.classList.contains("translate-y-full")
      drawerBtn.classList.toggle("bg-terminal-green", drawerOpen)
      drawerBtn.classList.toggle("text-stone-800", drawerOpen)
    }

    const sidebarPanel = document.getElementById("sidebar-panel")
    const sidebarBtn = document.getElementById("mobile-sidebar-btn")
    if (sidebarBtn && sidebarPanel) {
      const sidebarOpen = !sidebarPanel.classList.contains("hidden")
      sidebarBtn.classList.toggle("bg-terminal-green", sidebarOpen)
      sidebarBtn.classList.toggle("text-stone-800", sidebarOpen)
    }
  }
}
