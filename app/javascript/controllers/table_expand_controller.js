import { Controller } from "@hotwired/stimulus"

// Full-viewport table mode (shared/_asset_table). The state itself is a cookie
// rendered by the server, so this controller only adds the two things the
// markup can't express: keeping the page behind the overlay from scrolling,
// and Escape as a second way out.
export default class extends Controller {
  static targets = ["exit"]
  static values = { expanded: Boolean }

  connect() {
    if (!this.expandedValue) return
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    if (!this.expandedValue) return
    document.removeEventListener("keydown", this.onKeydown)
    document.body.style.overflow = ""
  }

  onKeydown(event) {
    if (event.key !== "Escape" || !this.hasExitTarget) return
    // An open column picker owns Escape first — it closes, the overlay stays.
    if (this.element.querySelector("[data-menu-target='panel']:not(.hidden)")) return
    this.exitTarget.requestSubmit()
  }
}
