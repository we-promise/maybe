import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["connectionResult"]

  connect() {
    console.log("Langfuse settings controller connected")
  }

  testConnection() {
    // Show loading state
    const resultElement = document.getElementById("connection-result")
    resultElement.innerHTML = `
      <div class="flex items-center gap-2 text-sm">
        <svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Testing connection to Langfuse...
      </div>
    `

    // Make API request
    fetch("/settings/langfuse/test_connection", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        resultElement.innerHTML = `
          <div class="flex items-center gap-2 text-sm text-green-600 dark:text-green-400">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            ${data.message}
          </div>
        `
      } else {
        resultElement.innerHTML = `
          <div class="flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
            ${data.message}
          </div>
        `
      }
    })
    .catch(error => {
      resultElement.innerHTML = `
        <div class="flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          Connection error: ${error.message}
        </div>
      `
    })
  }

  viewDashboard() {
    // Open Langfuse dashboard in new tab
    window.open(document.querySelector("p.font-mono").innerText, "_blank")
  }
}
