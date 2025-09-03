import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { loadingText: String }

  showLoading() {
    // Don't prevent form submission, just show loading state
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.setAttribute("aria-disabled", "true")
      this.buttonTarget.setAttribute("aria-busy", "true")
      this.buttonTarget.innerHTML = `
        <span class="inline-flex items-center gap-2">
          <span class="animate-spin rounded-full h-4 w-4 border-b-2 border-current" aria-hidden="true"></span>
          <span>${this.loadingTextValue || 'Loading...'}</span>
        </span>
      `
    }
  }
}