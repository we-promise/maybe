import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="resizable"
export default class extends Controller {
  static targets = ["element"];
  static values = {
    direction: String,
    minWidth: Number,
    maxWidth: Number,
    storageKey: String
  };

  connect() {
    // Default values if not specified
    this.directionValue = this.directionValue || "horizontal";
    this.minWidthValue = this.minWidthValue || 400;
    this.maxWidthValue = this.maxWidthValue || 1000;
    this.storageKeyValue = this.storageKeyValue || "resizable-width";

    // Set initial width from localStorage if available
    const savedWidth = localStorage.getItem(this.storageKeyValue);
    if (savedWidth) {
      this.elementTarget.style.width = `${savedWidth}px`;
    }

    // Create and append the resize handle
    this.createResizeHandle();
  }

  createResizeHandle() {
    this.resizeHandle = document.createElement("div");
    this.resizeHandle.classList.add("resize-handle", "resize-handle-horizontal");
    this.resizeHandle.style.position = "absolute";
    this.resizeHandle.style.top = "0";
    this.resizeHandle.style.left = "0";
    this.resizeHandle.style.bottom = "0";
    this.resizeHandle.style.width = "5px";
    this.resizeHandle.style.cursor = "ew-resize";
    this.resizeHandle.style.zIndex = "100";
    
    // Add a subtle visual indicator when hovering over the handle
    this.resizeHandle.addEventListener("mouseenter", () => {
      this.resizeHandle.style.backgroundColor = "rgba(0, 0, 0, 0.1)";
    });
    
    this.resizeHandle.addEventListener("mouseleave", () => {
      if (!this.isResizing) {
        this.resizeHandle.style.backgroundColor = "transparent";
      }
    });

    this.elementTarget.style.position = "relative";
    this.elementTarget.appendChild(this.resizeHandle);
    
    // Event listeners for resize behavior
    this.resizeHandle.addEventListener("mousedown", this.startResize.bind(this));
  }

  startResize(event) {
    this.isResizing = true;
    this.initialWidth = this.elementTarget.offsetWidth;
    this.initialX = event.clientX;
    
    // Add visual feedback during resize
    this.resizeHandle.style.backgroundColor = "rgba(0, 0, 0, 0.2)";
    document.body.style.cursor = "ew-resize";
    
    // Add event listeners for resize movement and end
    document.addEventListener("mousemove", this.resizeMove.bind(this));
    document.addEventListener("mouseup", this.endResize.bind(this));
    
    // Prevent text selection during resize
    event.preventDefault();
  }

  resizeMove(event) {
    if (!this.isResizing) return;
    
    const diff = this.initialX - event.clientX;
    let newWidth = this.initialWidth + diff;
    
    // Enforce min/max constraints
    newWidth = Math.max(this.minWidthValue, Math.min(this.maxWidthValue, newWidth));
    
    this.elementTarget.style.width = `${newWidth}px`;
  }

  endResize() {
    if (!this.isResizing) return;
    
    this.isResizing = false;
    this.resizeHandle.style.backgroundColor = "transparent";
    document.body.style.cursor = "";
    
    // Remove event listeners
    document.removeEventListener("mousemove", this.resizeMove);
    document.removeEventListener("mouseup", this.endResize);
    
    // Store current width in localStorage for persistence
    localStorage.setItem(this.storageKeyValue, this.elementTarget.offsetWidth);
  }
}
