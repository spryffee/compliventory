import { Controller } from "@hotwired/stimulus"

// Submits the surrounding form when an input changes — used by the admin
// role picker so a select change saves without a separate button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
