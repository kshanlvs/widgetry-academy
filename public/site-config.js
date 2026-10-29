// ===== Widgetry Academy: site settings =====
// Edit only the values in quotes, then redeploy (firebase deploy --only hosting).

window.WIDGETRY = {
  // Razorpay Payment Button IDs (start with "pl_"). Leave "" to show "Online payment opening soon".
  // Use TEST IDs only on a preview channel; on the live site use LIVE IDs or leave empty.
  razorpay: {
    regular:   "pl_Tl4tO3qkfF95TV",   // ₹4,999
    booking:   "pl_Tl4y52Nbm6N2QY"    // ₹2,500 – pay in 2 parts
  },

  // ---- Next batch (shown in the hero, fees section and WhatsApp messages) ----
  batch: {
    name:      "Batch 1",
    startDate: "Saturday, 17 October 2026", // fallback: live details are edited in Admin → Next batch
    days:      "Saturdays & Sundays",
    time:      "11:00 AM – 2:00 PM IST", // e.g. "10:00 AM – 12:00 PM IST"
    mode:      "Live online",            // e.g. "Live online (Google Meet)"
    demo:      "",                       // e.g. "Free demo: Sunday, 26 October, 11 AM"
    seatsLeft: null                      // seats left in the batch, e.g. 7 (null = hide). Keep it honest.
  },

  // ---- Contact (Contact page, policy pages, WhatsApp button) ----
  whatsapp:     "918617692683",       // WhatsApp number with country code, digits only, e.g. "919876543210". Empty = no WhatsApp button.
  contactEmail: "kishantechdev@gmail.com", // shown on the Contact page and policy pages
  contactPhone: "",                   // e.g. "+91 98765 43210" (optional)
  instagram:    "widgetry.academy",   // Instagram handle without @
  address:      "Kolkata, West Bengal, India", // shown on the Contact page (city only, no street address)
  udyam:        "UDYAM-WB-22-0009252",  // MSME registration number
  ownerName:    "Kishan Kumar Sharma",// Legal name used for Razorpay KYC

  // ---- Tracking ----
  metaPixelId:  "",                   // Meta (Facebook/Instagram) Pixel ID, digits only. Empty = off.
  gaId:         ""                    // Google Analytics 4 Measurement ID, e.g. "G-ABC123XYZ". Empty = off.
};

// Google Analytics (loads only when gaId is set; never on the admin or student dashboard pages)
(function () {
  var id = (window.WIDGETRY || {}).gaId || "";
  if (!/^G-[A-Z0-9]+$/i.test(id) || /\/(admin|pages\/dashboard|pages\/profile|pages\/receipt)\.html/.test(location.pathname)) return;
  var s = document.createElement("script"); s.async = true; s.src = "https://www.googletagmanager.com/gtag/js?id=" + id;
  document.head.appendChild(s);
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () { dataLayer.push(arguments); };
  gtag("js", new Date()); gtag("config", id);
})();
