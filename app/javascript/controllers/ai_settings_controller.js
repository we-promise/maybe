import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["providerOption", "providerSettings", "connectionResult", "openrouterApiKey", "ollamaBaseUrl", "modelSelect"]
  static values = { currentProvider: String }

  toggleProvider(event) {
    const selectedProvider = event.target.value
    
    // Update UI to show/hide provider-specific settings
    this.providerSettingsTargets.forEach(settings => {
      const provider = settings.dataset.provider
      
      if (provider === selectedProvider) {
        settings.style.display = "block"
      } else {
        settings.style.display = "none"
      }
    })

    // Update visual selection of provider options
    this.providerOptionTargets.forEach(option => {
      const provider = option.dataset.provider
      
      if (provider === selectedProvider) {
        option.classList.add("border-primary", "bg-surface-hover")
        option.classList.remove("border-secondary")
      } else {
        option.classList.remove("border-primary", "bg-surface-hover")
        option.classList.add("border-secondary")
      }
    })

    // Clear previous connection results
    this.connectionResultTargets.forEach(result => {
      result.innerHTML = ""
    })
  }

  async testConnection(event) {
    const button = event.currentTarget
    const provider = button.dataset.provider
    
    // Show loading state
    const originalText = button.innerHTML
    button.innerHTML = `<svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>Testing...`
    button.disabled = true

    // Get provider-specific parameters
    const params = { provider: provider }
    
    if (provider === "openrouter") {
      const apiKeyField = this.hasOpenrouterApiKeyTarget ? this.openrouterApiKeyTarget : null
      if (apiKeyField?.value && apiKeyField.value !== "********") {
        params.api_key = apiKeyField.value
      }
    } else if (provider === "ollama") {
      const baseUrlField = this.hasOllamaBaseUrlTarget ? this.ollamaBaseUrlTarget : null
      if (baseUrlField?.value) {
        params.base_url = baseUrlField.value
      }
    }

    try {
      const response = await fetch("/settings/ai/test_connection", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(params)
      })

      const data = await response.json()
      
      // Find the connection result element for this provider
      const resultElement = button.parentElement.querySelector('[data-ai-settings-target="connectionResult"]')
      
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
    } catch (error) {
      const resultElement = button.parentElement.querySelector('[data-ai-settings-target="connectionResult"]')
      resultElement.innerHTML = `
        <div class="flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          Connection failed: ${error.message}
        </div>
      `
    } finally {
      // Restore button state
      button.innerHTML = originalText
      button.disabled = false
    }
  }

  connect() {
    // Initialize the correct provider settings on page load
    const currentProvider = this.currentProviderValue || "openrouter"
    const currentProviderRadio = this.element.querySelector(`input[value="${currentProvider}"]`)
    
    if (currentProviderRadio) {
      currentProviderRadio.checked = true
      this.toggleProvider({ target: currentProviderRadio })
    }
  }
}
