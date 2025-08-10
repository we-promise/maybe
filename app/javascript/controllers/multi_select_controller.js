import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener('mousedown', this.toggleOption);
  }

  disconnect() {
    this.element.removeEventListener('mousedown', this.toggleOption);
  }

  toggleOption = (e) => {
    const option = e.target;
    if (option.tagName === 'OPTION') {
      e.preventDefault();
      option.selected = !option.selected;
      const event = new Event('change', { bubbles: true });
      this.element.dispatchEvent(event);
    }
  }
}