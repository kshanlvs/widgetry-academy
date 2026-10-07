/* ===== UI Utilities ===== */

/**
 * Show toast notification
 * @param {string} message - Notification message
 * @param {string} type - Notification type (success, error, warning, info)
 * @param {number} duration - Duration in ms (default 3000)
 */
export function showToast(message, type = "info", duration = 3000) {
  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => {
    toast.remove();
  }, duration);
}

/**
 * Show loading spinner
 * @param {string} message - Loading message
 * @returns {HTMLElement} Spinner element
 */
export function showLoading(message = "Loading...") {
  const container = document.createElement("div");
  container.className = "flex center"
  container.innerHTML = `
    <div class="spinner"></div>
    <span>${message}</span>
  `;
  return container;
}

/**
 * Show modal
 * @param {string} title - Modal title
 * @param {string} content - Modal content (HTML)
 * @param {array} buttons - Array of button configs {text, onClick, className}
 * @returns {HTMLElement} Modal element
 */
export function showModal(title, content, buttons = []) {
  const modal = document.createElement("div");
  modal.className = "modal";

  let buttonsHTML = "";
  if (buttons.length > 0) {
    buttonsHTML = `
      <div class="flex" style="gap: 8px; margin-top: 20px;">
        ${buttons
          .map(
            (btn) => `
          <button class="btn ${btn.className || ''}" data-action="${btn.action}">
            ${btn.text}
          </button>
        `
          )
          .join("")}
      </div>
    `;
  }

  modal.innerHTML = `
    <div class="modal-content animate-slide-up">
      <div class="modal-header">
        <h3>${title}</h3>
        <button class="modal-close" aria-label="Close">×</button>
      </div>
      <div class="modal-body">
        ${content}
        ${buttonsHTML}
      </div>
    </div>
  `;

  // Close button handler
  modal.querySelector(".modal-close").addEventListener("click", () => {
    modal.remove();
  });

  // Button handlers
  buttons.forEach((btn) => {
    const button = modal.querySelector(`[data-action="${btn.action}"]`);
    if (button && btn.onClick) {
      button.addEventListener("click", () => {
        btn.onClick();
        modal.remove();
      });
    }
  });

  // Close on background click
  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      modal.remove();
    }
  });

  document.body.appendChild(modal);
  return modal;
}

/**
 * Validate email
 * @param {string} email - Email to validate
 * @returns {boolean}
 */
export function validateEmail(email) {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

/**
 * Validate phone number (Indian format)
 * @param {string} phone - Phone to validate
 * @returns {boolean}
 */
export function validatePhone(phone) {
  const regex = /^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$/;
  return regex.test(phone);
}

/**
 * Format date
 * @param {Date|string} date - Date to format
 * @param {string} format - Format string (default 'YYYY-MM-DD')
 * @returns {string}
 */
export function formatDate(date, format = "YYYY-MM-DD") {
  if (!date) return "";
  const d = new Date(date);

  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const hours = String(d.getHours()).padStart(2, "0");
  const minutes = String(d.getMinutes()).padStart(2, "0");

  return format
    .replace("YYYY", year)
    .replace("MM", month)
    .replace("DD", day)
    .replace("HH", hours)
    .replace("mm", minutes);
}

/**
 * Format currency (INR)
 * @param {number} amount - Amount to format
 * @returns {string}
 */
export function formatCurrency(amount) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
  }).format(amount);
}

/**
 * Debounce function
 * @param {function} func - Function to debounce
 * @param {number} wait - Wait time in ms
 * @returns {function}
 */
export function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Clear form
 * @param {HTMLFormElement} form - Form to clear
 */
export function clearForm(form) {
  form.reset();
  form.querySelectorAll(".form-group.error").forEach((group) => {
    group.classList.remove("error");
    const error = group.querySelector(".form-error");
    if (error) error.remove();
  });
}

/**
 * Show form error
 * @param {HTMLElement} formGroup - Form group element
 * @param {string} message - Error message
 */
export function showFormError(formGroup, message) {
  formGroup.classList.add("error");
  let errorEl = formGroup.querySelector(".form-error");
  if (!errorEl) {
    errorEl = document.createElement("div");
    errorEl.className = "form-error";
    formGroup.appendChild(errorEl);
  }
  errorEl.textContent = message;
}

/**
 * Clear form error
 * @param {HTMLElement} formGroup - Form group element
 */
export function clearFormError(formGroup) {
  formGroup.classList.remove("error");
  const errorEl = formGroup.querySelector(".form-error");
  if (errorEl) errorEl.remove();
}

/**
 * Disable button
 * @param {HTMLButtonElement} button - Button element
 * @param {boolean} disabled - Disable state
 */
export function setButtonDisabled(button, disabled) {
  button.disabled = disabled;
  if (disabled) {
    button.setAttribute("aria-busy", "true");
    button.style.opacity = "0.6";
  } else {
    button.removeAttribute("aria-busy");
    button.style.opacity = "1";
  }
}

/**
 * Load script dynamically
 * @param {string} src - Script URL
 * @returns {Promise<void>}
 */
export function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

/**
 * Get query parameter
 * @param {string} name - Parameter name
 * @returns {string|null}
 */
export function getQueryParam(name) {
  const params = new URLSearchParams(window.location.search);
  return params.get(name);
}

/**
 * Update URL params
 * @param {object} params - Parameters to add
 */
export function updateURLParams(params) {
  const searchParams = new URLSearchParams(window.location.search);
  Object.keys(params).forEach((key) => {
    searchParams.set(key, params[key]);
  });
  window.history.pushState(
    {},
    "",
    `${window.location.pathname}?${searchParams.toString()}`
  );
}

/**
 * Animate element on scroll
 * @param {string} selector - Element selector
 * @param {string} className - Animation class
 */
export function observeElements(selector, className = "animate-fade-in") {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add(className);
        observer.unobserve(entry.target);
      }
    });
  });

  document.querySelectorAll(selector).forEach((el) => observer.observe(el));
}
