import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dialog"
export default class extends Controller {
  static targets = ["leftSidebar", "rightSidebar", "mobileSidebar"];
  static classes = [
    "expandedSidebar",
    "collapsedSidebar",
    "expandedTransition",
    "collapsedTransition",
  ];

  openMobileSidebar() {
    this.mobileSidebarTarget.classList.remove("hidden");
  }

  closeMobileSidebar() {
    this.mobileSidebarTarget.classList.add("hidden");
  }

  toggleLeftSidebar() {
    const isOpen = this.leftSidebarTarget.classList.contains("w-full");
    this.#updateUserPreference("show_sidebar", !isOpen);
    this.#toggleSidebarWidth(this.leftSidebarTarget, isOpen);
  }

  toggleRightSidebar() {
    const isOpen = this.rightSidebarTarget.classList.contains("w-full");
    this.#updateUserPreference("show_ai_sidebar", !isOpen);
    this.#toggleSidebarWidth(this.rightSidebarTarget, isOpen);
  }

  #toggleSidebarWidth(el, isCurrentlyOpen) {
    if (isCurrentlyOpen) {
      el.classList.remove(...this.expandedSidebarClasses);
      el.classList.add(...this.collapsedSidebarClasses);
      
      // If this is the right sidebar (chat), remove the custom width 
      if (el === this.rightSidebarTarget) {
        el.style.width = "";
      }
    } else {
      el.classList.add(...this.expandedSidebarClasses);
      el.classList.remove(...this.collapsedSidebarClasses);
      
      // If this is the right sidebar (chat), restore the custom width if it exists
      if (el === this.rightSidebarTarget) {
        const savedWidth = localStorage.getItem("chat-sidebar-width");
        if (savedWidth) {
          el.style.width = `${savedWidth}px`;
        }
      }
    }
  }

  #updateUserPreference(field, value) {
    fetch(`/users/${this.userIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        Accept: "application/json",
      },
      body: new URLSearchParams({
        [`user[${field}]`]: value,
      }).toString(),
    });
  }
}
